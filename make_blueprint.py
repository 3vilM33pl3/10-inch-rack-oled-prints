#!/usr/bin/env python3
"""Blueprint-style technical drawing of oled_display_rack_1u.scad.

Parses the numeric constants straight out of the .scad file (so the drawing
cannot drift from the model), recomputes the same derived values the model
uses, and emits a white-on-blue dimensioned SVG plus a PNG (via rsvg-convert
when available). Stdlib only.

Views: FRONT (full faceplate), SECTION A-A (vertical cut through display 1,
offset from the wire gap), and a back-side POCKET DETAIL. Values marked
"MEASURE ME" in the scad carry a * and a footnote.
"""

from __future__ import annotations

import math
import re
import shutil
import subprocess
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCAD = HERE / "oled_display_rack_1u.scad"
OUT_SVG = HERE / "oled_display_rack_1u_blueprint.svg"
OUT_PNG = HERE / "oled_display_rack_1u_blueprint.png"

# ---------------------------------------------------------------------------
# scad parameter extraction
# ---------------------------------------------------------------------------

PARAM_RE = re.compile(r"^\s*([a-z][a-z0-9_]*)\s*=\s*(-?\d+(?:\.\d+)?)\s*;", re.M)


def parse_params(text: str) -> dict[str, float]:
    return {name: float(val) for name, val in PARAM_RE.findall(text)}


def fnum(v: float) -> str:
    """1 decimal max, no trailing zeros: 250, 43.6, 31.75 stays 31.75."""
    s = f"{v:g}"
    return s


# ---------------------------------------------------------------------------
# minimal SVG builder
# ---------------------------------------------------------------------------

BG = "#0d3b66"          # blueprint blue
INK = "#f5f9ff"         # near-white lines and text
FAINT = "rgba(245,249,255,0.10)"

STYLE = f"""
  .outline {{ fill: none; stroke: {INK}; stroke-width: 2.2; }}
  .thin    {{ fill: none; stroke: {INK}; stroke-width: 1.3; }}
  .hidden  {{ fill: none; stroke: {INK}; stroke-width: 1.3; stroke-dasharray: 7 5; }}
  .center  {{ fill: none; stroke: {INK}; stroke-width: 1.1; stroke-dasharray: 14 4 3 4; }}
  .dim     {{ fill: none; stroke: {INK}; stroke-width: 1.1; }}
  .hatch   {{ fill: url(#hatch); stroke: {INK}; stroke-width: 2.2; }}
  .bgfill  {{ fill: {BG}; stroke: none; }}
  text     {{ fill: {INK}; font-family: 'DejaVu Sans Mono', monospace; }}
  .dimtxt  {{ font-size: 17px; }}
  .lbl     {{ font-size: 20px; letter-spacing: 2px; }}
  .small   {{ font-size: 14px; }}
  .title   {{ font-size: 24px; letter-spacing: 3px; }}
"""


class Svg:
    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.body: list[str] = []

    def add(self, el: str) -> None:
        self.body.append(el)

    def line(self, x1: float, y1: float, x2: float, y2: float, cls: str = "thin") -> None:
        self.add(f'<line class="{cls}" x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}"/>')

    def rect(self, x: float, y: float, w: float, h: float, cls: str = "thin") -> None:
        self.add(f'<rect class="{cls}" x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}"/>')

    def circle(self, cx: float, cy: float, r: float, cls: str = "thin") -> None:
        self.add(f'<circle class="{cls}" cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}"/>')

    def poly(self, pts: list[tuple[float, float]], cls: str = "thin") -> None:
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        self.add(f'<polygon class="{cls}" points="{p}"/>')

    def text(
        self, x: float, y: float, s: str, cls: str = "dimtxt",
        anchor: str = "middle", rotate: float | None = None,
    ) -> None:
        tr = f' transform="rotate({rotate:.0f} {x:.1f} {y:.1f})"' if rotate else ""
        self.add(
            f'<text class="{cls}" x="{x:.1f}" y="{y:.1f}" text-anchor="{anchor}"{tr}>{s}</text>'
        )

    # --- dimensioning ------------------------------------------------------

    def arrow(self, x: float, y: float, ang_deg: float) -> None:
        """Solid arrowhead with the tip at (x, y), pointing toward ang_deg."""
        a = math.radians(ang_deg)
        L, W = 12.0, 4.2
        bx, by = x - L * math.cos(a), y - L * math.sin(a)
        nx, ny = -math.sin(a), math.cos(a)
        self.add(
            f'<polygon fill="{INK}" points="{x:.1f},{y:.1f} '
            f"{bx + W * nx:.1f},{by + W * ny:.1f} {bx - W * nx:.1f},{by - W * ny:.1f}\"/>"
        )

    def dim_h(self, x1: float, x2: float, y: float, label: str,
              ext_y: float | None = None) -> None:
        """Horizontal dimension between x1..x2 at height y; extension lines
        run from ext_y (the measured edge) to just past the dim line."""
        if ext_y is not None:
            over = 5 if y > ext_y else -5
            self.line(x1, ext_y, x1, y + over, "dim")
            self.line(x2, ext_y, x2, y + over, "dim")
        self.line(x1, y, x2, y, "dim")
        self.arrow(x1, y, 180)
        self.arrow(x2, y, 0)
        self.text((x1 + x2) / 2, y - 7, label)

    def dim_v(self, y1: float, y2: float, x: float, label: str,
              ext_x: float | None = None) -> None:
        if ext_x is not None:
            over = 5 if x > ext_x else -5
            self.line(ext_x, y1, x + over, y1, "dim")
            self.line(ext_x, y2, x + over, y2, "dim")
        self.line(x, y1, x, y2, "dim")
        self.arrow(x, y1, 270)
        self.arrow(x, y2, 90)
        self.text(x - 7, (y1 + y2) / 2, label, rotate=-90)

    def leader(self, x: float, y: float, dx: float, dy: float, label: str,
               anchor: str = "start") -> None:
        """Arrow at (x,y), elbow at (x+dx, y+dy), horizontal tail, label."""
        ang = math.degrees(math.atan2(-dy, -dx))
        self.arrow(x, y, ang)
        ex, ey = x + dx, y + dy
        tail = 14 if anchor == "start" else -14
        self.line(x, y, ex, ey, "dim")
        self.line(ex, ey, ex + tail, ey, "dim")
        tx = ex + tail + (6 if anchor == "start" else -6)
        self.text(tx, ey + 5, label, anchor=anchor)

    def render(self) -> str:
        grid = 25
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" '
            f'width="{self.w}" height="{self.h}">\n'
            f"<style>{STYLE}</style>\n"
            "<defs>\n"
            f'  <pattern id="hatch" width="9" height="9" patternTransform="rotate(45)" '
            'patternUnits="userSpaceOnUse">'
            f'<line x1="0" y1="0" x2="0" y2="9" stroke="{INK}" stroke-width="1.1"/></pattern>\n'
            f'  <pattern id="grid" width="{grid}" height="{grid}" patternUnits="userSpaceOnUse">'
            f'<path d="M {grid} 0 L 0 0 0 {grid}" fill="none" stroke="{FAINT}" '
            'stroke-width="1"/></pattern>\n'
            "</defs>\n"
            f'<rect width="{self.w}" height="{self.h}" fill="{BG}"/>\n'
            f'<rect width="{self.w}" height="{self.h}" fill="url(#grid)"/>\n'
            + "\n".join(self.body)
            + "\n</svg>\n"
        )


# ---------------------------------------------------------------------------
# the drawing
# ---------------------------------------------------------------------------

def main() -> None:
    p = parse_params(SCAD.read_text())

    # derived values, same formulas as the scad
    panel_x, panel_y, panel_z = p["panel_x"], p["panel_y"], p["panel_z"]
    hole_1_x = (panel_x - p["rack_hole_spacing_x"]) / 2
    hole_2_x = panel_x - hole_1_x
    hole_1_y = (panel_y - p["rack_hole_spacing_y"]) / 2
    hole_2_y = panel_y - hole_1_y
    pocket_x = p["oled_pcb_x"] + 2 * p["oled_pocket_clearance"]
    pocket_y = p["oled_pcb_y"] + 2 * p["oled_pocket_clearance"]
    frame_x = pocket_x + 2 * p["oled_wall_xy"]
    frame_y = pocket_y + 2 * p["oled_wall_xy"]
    n = int(p["oled_count"])
    pitch = p["oled_pitch"]
    center_y = panel_y / 2
    win_cy = center_y + p["oled_window_offset_y"]
    oled_cx = [panel_x / 2 - (n - 1) * pitch / 2 + i * pitch for i in range(n)]

    svg = Svg(1600, 1250)

    # sheet border
    svg.rect(16, 16, 1568, 1218, "thin")
    svg.rect(34, 34, 1532, 1182, "outline")

    # =======================================================================
    # FRONT VIEW  (scale S1 px/mm), model origin = panel bottom-left
    # =======================================================================
    S1 = 5.0
    ox, oy = 175.0, 415.0  # svg coords of model (0, 0); model +y goes up

    def fx(x: float) -> float:
        return ox + S1 * x

    def fy(y: float) -> float:
        return oy - S1 * y

    svg.rect(fx(0), fy(panel_y), S1 * panel_x, S1 * panel_y, "outline")

    # rack holes + centerlines
    for hx in (hole_1_x, hole_2_x):
        for hy in (hole_1_y, hole_2_y):
            svg.circle(fx(hx), fy(hy), S1 * p["rack_hole_diameter"] / 2, "thin")
        svg.line(fx(hx), fy(hole_1_y) + 26, fx(hx), fy(hole_2_y) - 26, "center")
    for hy in (hole_1_y, hole_2_y):
        svg.line(fx(hole_1_x) - 26, fy(hy), fx(hole_1_x) + 26, fy(hy), "center")
        svg.line(fx(hole_2_x) - 26, fy(hy), fx(hole_2_x) + 26, fy(hy), "center")

    # windows, hidden pocket frames, centerlines
    for cx in oled_cx:
        svg.rect(fx(cx - p["oled_window_x"] / 2), fy(win_cy + p["oled_window_y"] / 2),
                 S1 * p["oled_window_x"], S1 * p["oled_window_y"], "outline")
        svg.rect(fx(cx - frame_x / 2), fy(center_y + frame_y / 2),
                 S1 * frame_x, S1 * frame_y, "hidden")
        svg.line(fx(cx), fy(panel_y) - 16, fx(cx), fy(0) + 16, "center")
    svg.line(fx(0) - 20, fy(win_cy), fx(panel_x) + 20, fy(win_cy), "center")

    # section cut line A-A through display 1, offset past the wire gap
    sec_x = oled_cx[0] + 10
    svg.line(fx(sec_x), fy(panel_y) - 34, fx(sec_x), fy(0) + 34, "center")
    for yy, ang in ((fy(panel_y) - 34, 180), (fy(0) + 34, 180)):
        svg.arrow(fx(sec_x) - 2, yy, ang)
        svg.text(fx(sec_x) - 16, yy + 6, "A", "lbl", anchor="end")

    # dimensions
    svg.dim_h(fx(0), fx(panel_x), fy(panel_y) - 52, fnum(panel_x), ext_y=fy(panel_y))
    svg.dim_v(fy(panel_y), fy(0), fx(0) - 52, fnum(panel_y), ext_x=fx(0))
    svg.dim_h(fx(hole_1_x), fx(hole_2_x), fy(0) + 48,
              fnum(p["rack_hole_spacing_x"]) + " *", ext_y=fy(hole_1_y))
    svg.dim_v(fy(hole_2_y), fy(hole_1_y), fx(panel_x) + 52,
              fnum(p["rack_hole_spacing_y"]), ext_x=fx(hole_2_x))
    svg.dim_h(fx(oled_cx[2]), fx(oled_cx[3]), fy(panel_y) - 22, fnum(pitch))
    svg.dim_h(fx(oled_cx[3] - p["oled_window_x"] / 2),
              fx(oled_cx[3] + p["oled_window_x"] / 2),
              fy(0) + 26, fnum(p["oled_window_x"]),
              ext_y=fy(win_cy - p["oled_window_y"] / 2))
    svg.dim_v(fy(win_cy + p["oled_window_y"] / 2), fy(win_cy - p["oled_window_y"] / 2),
              fx(oled_cx[3] + p["oled_window_x"] / 2) + 34, fnum(p["oled_window_y"]),
              ext_x=fx(oled_cx[3] + p["oled_window_x"] / 2))
    svg.leader(fx(hole_1_x) - S1 * p["rack_hole_diameter"] / 2 / 1.41,
               fy(hole_2_y) - S1 * p["rack_hole_diameter"] / 2 / 1.41,
               -40, -32, f"4x ⌀{fnum(p['rack_hole_diameter'])}", anchor="end")

    svg.text(fx(panel_x / 2), fy(0) + 92, "FRONT VIEW", "lbl")
    svg.text(fx(0), fy(0) + 116,
             f"WINDOW CENTERS {fnum(-p['oled_window_offset_y'])} BELOW PANEL CENTERLINE"
             f" — POCKETS (DASHED) ON BACK", "small", anchor="start")

    # =======================================================================
    # SECTION A-A  (scale S2 px/mm), profile in (y, z), z = 0 at front face
    # =======================================================================
    S2 = 12.0
    sx0, sz0 = 170.0, 1000.0  # svg coords of model (y=0, z=0); z grows up

    def sy(y: float) -> float:
        return sx0 + S2 * y

    def sz(z: float) -> float:
        return sz0 - S2 * z

    win_lo = win_cy - p["oled_window_y"] / 2
    win_hi = win_cy + p["oled_window_y"] / 2
    wall_in_lo = center_y - pocket_y / 2      # pocket opening edges
    wall_in_hi = center_y + pocket_y / 2
    wall_out_lo = center_y - frame_y / 2
    wall_out_hi = center_y + frame_y / 2
    rel_lo = wall_in_hi - p["oled_solder_relief_y"]
    rel_z = panel_z - p["oled_solder_relief_depth"]
    wall_top = panel_z + p["oled_wall_z"]
    flange_top = panel_z + p["flange_z"]

    # left piece: y 0 .. window low edge (bottom flange + pocket bottom wall)
    left = [
        (0, 0), (win_lo, 0), (win_lo, panel_z), (wall_in_lo, panel_z),
        (wall_in_lo, wall_top), (wall_out_lo, wall_top), (wall_out_lo, panel_z),
        (p["flange_y"], panel_z), (p["flange_y"], flange_top), (0, flange_top),
    ]
    # right piece: window high edge .. panel_y (relief groove, top wall, flange)
    right = [
        (win_hi, 0), (panel_y, 0), (panel_y, flange_top),
        (panel_y - p["flange_y"], flange_top), (panel_y - p["flange_y"], panel_z),
        (wall_out_hi, panel_z), (wall_out_hi, wall_top), (wall_in_hi, wall_top),
        (wall_in_hi, rel_z), (rel_lo, rel_z), (rel_lo, panel_z),
        (win_hi, panel_z),
    ]
    for piece in (left, right):
        svg.poly([(sy(y), sz(z)) for y, z in piece], "hatch")

    svg.dim_v(sz(panel_z), sz(0), sy(0) - 40, fnum(panel_z), ext_x=sy(0))
    svg.dim_v(sz(flange_top), sz(0), sy(panel_y) + 44, fnum(panel_z + p["flange_z"]),
              ext_x=sy(panel_y))
    svg.leader(sy((wall_out_hi + wall_in_hi) / 2), sz(wall_top), -26, -44,
               f"POCKET WALL, RISE {fnum(p['oled_wall_z'])}", anchor="end")
    svg.leader(sy(panel_y - p["flange_y"] / 2), sz(flange_top), 20, -36,
               f"FLANGE {fnum(p['flange_y'])} x {fnum(p['flange_z'])}")
    svg.leader(sy((rel_lo + wall_in_hi) / 2), sz(rel_z), 30, 42,
               f"SOLDER RELIEF, {fnum(p['oled_solder_relief_depth'])} DEEP *")
    svg.dim_h(sy(win_lo), sy(win_hi), sz(0) + 30, f"WINDOW {fnum(p['oled_window_y'])}",
              ext_y=sz(0))
    svg.text(sy(panel_y / 2), sz(0) + 78, "SECTION A-A", "lbl")
    svg.text(sy(panel_y / 2), sz(0) + 100, "FRONT FACE DOWN = PRINT ORIENTATION", "small")

    # =======================================================================
    # POCKET DETAIL, VIEW FROM BACK  (scale S3 px/mm), one pocket, centered
    # =======================================================================
    S3 = 12.0
    dcx, dcy = 1210.0, 740.0  # svg center of the pocket

    def dx(x: float) -> float:  # x measured from pocket center
        return dcx + S3 * x

    def dy(y: float) -> float:  # y from pocket center, model +y up
        return dcy - S3 * y

    hx_o, hy_o = frame_x / 2, frame_y / 2
    hx_i, hy_i = pocket_x / 2, pocket_y / 2
    gap = p["oled_wire_gap_x"] / 2
    notch = p["oled_notch_y"] / 2

    svg.rect(dx(-hx_o), dy(hy_o), S3 * frame_x, S3 * frame_y, "outline")
    svg.rect(dx(-hx_i), dy(hy_i), S3 * pocket_x, S3 * pocket_y, "outline")
    # wire gap: blank the top wall between +-gap, then stroke the gap edges
    svg.rect(dx(-gap) + 1, dy(hy_o) - 2, S3 * p["oled_wire_gap_x"] - 2,
             S3 * p["oled_wall_xy"] + 4, "bgfill")
    for s in (-1, 1):
        svg.line(dx(s * gap), dy(hy_o), dx(s * gap), dy(hy_i), "outline")
    # removal notches in both side walls
    for s in (-1, 1):
        x_in, x_out = dx(s * hx_i), dx(s * hx_o)
        svg.rect(min(x_in, x_out) - 1, dy(notch) + 1, abs(x_out - x_in) + 2,
                 S3 * p["oled_notch_y"] - 2, "bgfill")
        svg.line(min(x_in, x_out) - 1, dy(notch), max(x_in, x_out) + 1, dy(notch), "outline")
        svg.line(min(x_in, x_out) - 1, dy(-notch), max(x_in, x_out) + 1, dy(-notch), "outline")
    # solder relief band (on the panel floor, hidden edge)
    svg.rect(dx(-hx_i), dy(hy_i), S3 * pocket_x, S3 * p["oled_solder_relief_y"], "hidden")

    svg.dim_h(dx(-hx_i), dx(hx_i), dy(-hy_o) + 34, fnum(pocket_x), ext_y=dy(-hy_i))
    svg.dim_v(dy(hy_i), dy(-hy_i), dx(hx_o) + 40, fnum(pocket_y), ext_x=dx(hx_i))
    svg.dim_h(dx(-gap), dx(gap), dy(hy_o) - 26, fnum(p["oled_wire_gap_x"]), ext_y=dy(hy_o))
    svg.dim_v(dy(notch), dy(-notch), dx(-hx_o) - 36, fnum(p["oled_notch_y"]),
              ext_x=dx(-hx_o))
    svg.leader(dx(hx_o - p["oled_wall_xy"] / 2), dy(-hy_o) + 2, 30, 40,
               f"WALL {fnum(p['oled_wall_xy'])}")
    svg.leader(dx(0), dy(hy_i - p["oled_solder_relief_y"] / 2), 60, 54,
               f"SOLDER RELIEF BAND {fnum(p['oled_solder_relief_y'])}")
    svg.text(dcx, dy(-hy_o) + 88, "POCKET DETAIL", "lbl")
    svg.text(dcx, dy(-hy_o) + 110,
             f"VIEW FROM BACK — PCB {fnum(p['oled_pcb_x'])} x {fnum(p['oled_pcb_y'])} *"
             f" + {fnum(p['oled_pocket_clearance'])} CLEARANCE/SIDE", "small")

    # =======================================================================
    # title block + footnote
    # =======================================================================
    tb_x, tb_y, tb_w, tb_h = 966, 1126, 600, 90
    svg.rect(tb_x, tb_y, tb_w, tb_h, "outline")
    svg.line(tb_x, tb_y + 38, tb_x + tb_w, tb_y + 38, "thin")
    svg.line(tb_x + 300, tb_y + 38, tb_x + 300, tb_y + tb_h, "thin")
    svg.line(tb_x + 452, tb_y + 38, tb_x + 452, tb_y + tb_h, "thin")
    svg.text(tb_x + tb_w / 2, tb_y + 26, "OLED DISPLAY RACK — 1U / 10\" RACK", "title")
    svg.text(tb_x + 8, tb_y + 56, "oled_display_rack_1u.scad", "small", anchor="start")
    svg.text(tb_x + 8, tb_y + 76, "DRAWN: 3vilM33pl3", "small", anchor="start")
    svg.text(tb_x + 308, tb_y + 56, "UNITS: MM", "small", anchor="start")
    svg.text(tb_x + 308, tb_y + 76, f"DATE: {date.today().isoformat()}", "small", anchor="start")
    svg.text(tb_x + 460, tb_y + 56, "SHEET 1 OF 1", "small", anchor="start")
    svg.text(tb_x + 460, tb_y + 76, "PETG/PLA", "small", anchor="start")
    svg.text(60, 1200, "* MEASURE ME — VERIFY WITH CALIPERS AGAINST THE REAL "
             "MODULES / RACK BEFORE PRINTING", "small", anchor="start")

    OUT_SVG.write_text(svg.render())
    print(f"wrote {OUT_SVG}")

    if shutil.which("rsvg-convert"):
        subprocess.run(
            ["rsvg-convert", "-w", "2400", "-o", str(OUT_PNG), str(OUT_SVG)], check=True
        )
        print(f"wrote {OUT_PNG}")
    else:
        print("rsvg-convert not found; skipped PNG")


if __name__ == "__main__":
    main()
