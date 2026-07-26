// Homelab enclosure helper modules.
// OpenSCAD 2021.01, no external libraries (BOSL2 is not installed here; MCAD only).
// Millimetres throughout. Cutters follow the repo idiom: oversize height and a
// -1 Z offset so they pierce cleanly. Colours are cosmetic preview labels only.
//
// This is the first reusable-geometry library for the Homelab hardware work; the
// existing rpi5_case.scad / oled_display_rack_1u.scad had no shared lib. Keep the
// API small and parametric so a future case can reuse it.

lib_cyl_fn = 96;          // hole / rounding resolution (fine enough, fast preview)
lib_boolean_h = 60;       // oversize length for through-cutters

// --- primitives ------------------------------------------------------------

// Solid box with the 4 vertical edges rounded to radius r.
module rounded_box(size, r) {
    r_eff = min(r, size[0] / 2, size[1] / 2);
    linear_extrude(height = size[2])
        offset(r = r_eff) offset(delta = -r_eff)
            square([size[0], size[1]]);
}

// Hollow shell open at +Z: outer rounded box minus an inner cavity leaving
// `wall` on the 4 sides and `floor` on the bottom. Interior corners rounded too.
module shell(size, r, wall, floor) {
    difference() {
        rounded_box(size, r);
        translate([wall, wall, floor])
            rounded_box([size[0] - 2 * wall, size[1] - 2 * wall, size[2] - floor + 1],
                        max(0.1, r - wall));
    }
}

// --- fasteners / standoffs -------------------------------------------------

// PCB locating standoff: a post of dia boss_d and height h with a central pilot
// (pilot_d) through it and the part beneath. Used under the Pi mount holes.
// No top counterbore is needed: at h>=4 the post top sits below the splayed
// Active-Cooler push-pin barbs (~2mm under the PCB), so they never touch it.
module pcb_standoff(h, boss_d = 8, pilot_d = 2.3) {
    difference() {
        cylinder(h = h, d = boss_d, $fn = lib_cyl_fn);
        translate([0, 0, -1])
            cylinder(h = h + 2, d = pilot_d, $fn = lib_cyl_fn);
    }
}

// Boss for a brass heat-set threaded insert, installed from the +Z (open) face.
// insert_d/insert_depth are the melted-in pocket; MEASURE the insert before final.
module heatset_boss(h, boss_d = 7, insert_d = 4.0, insert_depth = 5) {
    difference() {
        cylinder(h = h, d = boss_d, $fn = lib_cyl_fn);
        translate([0, 0, h - insert_depth])
            cylinder(h = insert_depth + 1, d = insert_d, $fn = lib_cyl_fn);
    }
}

// Counterbored screw-hole cutter, cutting DOWN from z=0 (place at the face the
// screw head lands on). Shank clears the screw; head sinks into the cbore.
module screw_cbore_cut(shank_d = 3.4, head_d = 6.4, head_depth = 3, length = lib_boolean_h) {
    translate([0, 0, -length]) cylinder(h = length + 1, d = shank_d, $fn = lib_cyl_fn);
    translate([0, 0, -head_depth]) cylinder(h = head_depth + 1, d = head_d, $fn = lib_cyl_fn);
}

// --- cutters ---------------------------------------------------------------

// Rectangular through-cutter. pos = min corner [x,y,z], size = [x,y,z].
module box_cut(pos, size) {
    translate(pos) cube(size);
}

// Row of rounded through-slots for ventilation, cut through `thick` in Z.
// Slots run along +Y, laid out along +X starting at the origin.
module vent_slots(count, slot_w, slot_len, pitch, thick) {
    for (i = [0 : count - 1])
        translate([i * pitch, 0, -1])
            hull() {
                translate([0, slot_w / 2, 0])            cylinder(h = thick + 2, d = slot_w, $fn = lib_cyl_fn);
                translate([0, slot_len - slot_w / 2, 0]) cylinder(h = thick + 2, d = slot_w, $fn = lib_cyl_fn);
            }
}

// --- component capture -----------------------------------------------------

// Open capture pocket (walls only) that holds a PCB of [px,py] with `clearance`
// per side, walls `wall_t` thick and `wall_h` tall, growing +Z from its base.
// The board drops in and is bonded/taped; for the tamper gyro this gives the
// rigid coupling to the shell. Optional screw post at post_pos (local, from the
// inner pocket corner) for boards with a mount hole. Origin at the outer corner.
module component_pocket(px, py, wall_h = 5, wall_t = 2, clearance = 0.35,
                        post_d = 0, post_pilot = 2.5, post_pos = [0, 0],
                        notch_w = 0) {
    ox = px + 2 * clearance;
    oy = py + 2 * clearance;
    difference() {
        cube([ox + 2 * wall_t, oy + 2 * wall_t, wall_h]);
        translate([wall_t, wall_t, -1]) cube([ox, oy, wall_h + 2]);
        // fingernail removal notches in the two long walls
        if (notch_w > 0)
            for (sx = [wall_t / 2, ox + 1.5 * wall_t])
                translate([sx - notch_w / 2, (oy + 2 * wall_t - notch_w) / 2, -1])
                    cube([notch_w, notch_w, wall_h + 2]);
    }
    if (post_d > 0)
        translate([wall_t + post_pos[0], wall_t + post_pos[1], 0])
            difference() {
                cylinder(h = wall_h, d = post_d, $fn = lib_cyl_fn);
                translate([0, 0, -1]) cylinder(h = wall_h + 2, d = post_pilot, $fn = lib_cyl_fn);
            }
}

// --- OLED drop-in mount (generalised from oled_display_rack_1u.scad) --------
// The panel/lid is modelled with its OUTER face at z=0 and the interior at +Z
// (i.e. call these on the lid modelled outer-face-down). The glass noses into a
// window through the panel; the module PCB drops into a raised pocket frame on
// the inner face and is held with tape across the wall tops (screwless).

// Window cut through the panel for the visible glass. Panel thickness = panel_t.
module oled_window_cut(panel_t, win_x = 26, win_y = 15, offset_y = -2) {
    translate([-win_x / 2, offset_y - win_y / 2, -1])
        cube([win_x, win_y, panel_t + 2]);
}

// Raised pocket frame on the inner face (z = panel_t upward). Holds the PCB with
// `clearance` per side; a wire gap in the top wall passes the backward pins.
module oled_pocket_frame(panel_t, pcb_x = 27.5, pcb_y = 27.8, clearance = 0.25,
                          wall_xy = 2.4, wall_z = 4, wire_gap = 16, notch_y = 8) {
    pocket_x = pcb_x + 2 * clearance;
    pocket_y = pcb_y + 2 * clearance;
    frame_x = pocket_x + 2 * wall_xy;
    frame_y = pocket_y + 2 * wall_xy;
    difference() {
        translate([-frame_x / 2, -frame_y / 2, panel_t])
            cube([frame_x, frame_y, wall_z]);
        // pocket opening
        translate([-pocket_x / 2, -pocket_y / 2, panel_t - 1])
            cube([pocket_x, pocket_y, wall_z + 2]);
        // wire gap in the top wall (+Y)
        translate([-wire_gap / 2, pocket_y / 2 - 1, panel_t - 1])
            cube([wire_gap, wall_xy + 2, wall_z + 2]);
        // fingernail removal notches in the side walls
        for (side = [-1, 1])
            translate([side * (pocket_x / 2 + wall_xy / 2) - wall_xy / 2 - 1,
                       -notch_y / 2, panel_t - 1])
                cube([wall_xy + 2, notch_y, wall_z + 2]);
    }
}
