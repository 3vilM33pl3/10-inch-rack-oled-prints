// Raspberry Pi 5 Certificate-Authority enclosure.
//
// Houses: Pi 5 + official Active Cooler + Geekworm X1001 M.2 HAT with a full
// length 2280 SSD, a 0.96" SSD1306 OLED in the lid, a TCA9548A I2C multiplexer
// and an MPU-6050 gyro (rigidly bonded, for ATM-style move-detection lockdown).
//
// Layout (Pi laid flat, official-drawing axes: X along 85mm, Y along 56mm):
//   FRONT  = Pi USB/Ethernet edge (high X)  -> recessed open USB bay + 2 bosses
//   SIDE   = Pi USB-C/micro-HDMI edge (low Y)-> flush port tunnels
//   REAR   = margin behind the Pi (low X)    -> 2 lid bosses
//   GPIO   = Pi 40-pin edge (high Y)         -> component lane (mux + gyro), vents
// The Pi nearly fills the interior, so lid screw bosses live only in the REAR
// and FRONT margins (never over the board), and the mux/gyro sit in the GPIO
// lane. The front margin doubles as the recessed USB device bay.
//
// Verified stack (resolves the cooler-vs-HAT conflict): Pi -> Active Cooler on
// top (13.7mm) -> X1001 on 17mm F/F standoffs above the cooler -> SSD (top ~20
// above the PCB). Interior headroom is set so the OLED electronics (hanging from
// the lid) clear the SSD even directly above the HAT.
//
// PRINT: tray floor-down (open top up), lid OUTER-face-down (window + top smooth
// on the bed, pocket walls grow up). No supports; PETG or PLA, 4 perimeters.
// Print the coupons first and caliper every "MEASURE ME" before the full parts.

use <homelab_lib.scad>

render_mode = "assembly";  // "assembly" | "tray" | "lid" | "coupon_front" | "coupon_boss"

cyl_fn = 96;
eps = 0.01;

// ---------------------------------------------------------------------------
// Raspberry Pi 5 board + fit-tuned port offsets
// ---------------------------------------------------------------------------
pcb_x = 85;                 // board length (X)
pcb_y = 56;                 // board width  (Y)
pcb_th = 1.6;
pi_hole_inset = 3.5;        // mount-hole centre inset from each edge
pi_hole_dx = 58;            // hole grid, X
pi_hole_dy = 49;            // hole grid, Y

// Front edge (Pi X=85 face): Y offsets from the Y=0 corner.
// Fit-tuned in rpi5_case.scad against a real print.
front_eth_y  = 10;          // RJ45 centre
front_usb1_y = 29.6;        // lower stacked USB-A centre
front_usb2_y = 47.5;        // upper stacked USB-A centre
eth_cut  = [17, 15];        // [Y width, Z height] Ethernet window
usb_cut  = [16, 16];        // [Y width, Z height] stacked-USB window

// Side edge (Pi Y=0 face): X offsets from the X=0 corner (mechanical drawing).
side_usbc_x = 11.2;
side_hdmi0_x = 25.8;
side_hdmi1_x = 39.2;
usbc_cut = [11, 7];         // [X width, Z height]
hdmi_cut = [8, 6];          // [X width, Z height] micro-HDMI (generous)

// ---------------------------------------------------------------------------
// Stack heights above the PCB top surface -- MEASURE ME on the real stack
// ---------------------------------------------------------------------------
cooler_h = 13.7;            // Active Cooler height above PCB
hat_standoff = 17;          // Pi -> HAT F/F standoff
ssd_top_h = 20;             // top of the 2280 SSD above PCB
usb_conn_h = 16;            // stacked USB-A body height above PCB
oled_hang = 13;             // how far OLED electronics hang below its glass

// ---------------------------------------------------------------------------
// Enclosure shell
// ---------------------------------------------------------------------------
wall = 2.4;
floor_th = 2.4;
corner_r = 4;

clr = 0.4;                  // clearance on the low-Y (port) side; Pi sits close
rear_gap = 8;               // margin behind the Pi (rear lid bosses)
front_gap = 8;              // margin in front of the Pi (front bosses + USB bay)
gpio_lane = 26;             // component lane along the GPIO edge (mux + gyro)

standoff_below = 4;         // PCB underside above the floor (clears SD + cooler pins)
clearance_above_pcb = 33;   // headroom above PCB (clears stack AND lid-hung OLED)

// derived interior / exterior
interior_x = rear_gap + pcb_x + front_gap;
interior_y = clr + pcb_y + gpio_lane;
interior_z = standoff_below + pcb_th + clearance_above_pcb;
tray_h = floor_th + interior_z;

ext_x = interior_x + 2 * wall;
ext_y = interior_y + 2 * wall;

lid_th = 3;
lid_lip_h = 4;
lid_lip_clr = 0.3;
ext_z = tray_h + lid_th;

// PCB placement: rear edge at high-side of the rear margin, low-Y edge near wall
pcb_x0 = wall + rear_gap;                 // Pi X=0 corner
pcb_y0 = wall + clr;                      // Pi Y=0 corner
pcb_top_z = floor_th + standoff_below + pcb_th;
stack_top_z = pcb_top_z + ssd_top_h;
oled_bottom_z = ext_z - oled_hang;        // for the clearance assertion below

// Pi mount-hole positions (tray coordinates)
function pi_hole_xy() = [
    [pcb_x0 + pi_hole_inset,               pcb_y0 + pi_hole_inset],
    [pcb_x0 + pi_hole_inset + pi_hole_dx,  pcb_y0 + pi_hole_inset],
    [pcb_x0 + pi_hole_inset,               pcb_y0 + pi_hole_inset + pi_hole_dy],
    [pcb_x0 + pi_hole_inset + pi_hole_dx,  pcb_y0 + pi_hole_inset + pi_hole_dy]
];

// Lid screw bosses: rear pair + front pair, in the margins (clear of the board).
// Placed concentric with the rounded corners so each boss merges into the two
// corner walls -- far stronger than a free-standing post, and it fills the corner.
boss_inset = corner_r;
function boss_xy() = [
    [boss_inset,          boss_inset],
    [ext_x - boss_inset,  boss_inset],
    [boss_inset,          ext_y - boss_inset],
    [ext_x - boss_inset,  ext_y - boss_inset]
];

// Component-lane pocket placements (GPIO side, high Y, clear of the board+bosses)
mux_pos  = [26, 58];        // TCA9548A pocket outer corner  // MEASURE the board
gyro_pos = [66, 60];        // MPU-6050 pocket outer corner (rigid tamper sensor)

// sanity: OLED electronics must clear the SSD stack top
echo(str("OLED bottom z = ", oled_bottom_z, "  SSD top z = ", stack_top_z,
         "  clearance = ", oled_bottom_z - stack_top_z, "mm"));

// ---------------------------------------------------------------------------
// Front recessed USB bay + port windows (front wall at high X)
// ---------------------------------------------------------------------------
front_recess_depth = 5;                   // alcove depth into the outer wall
front_recess_margin = 5;                  // recess border around the ports
front_open_x = 6;                         // how far the window reaches inside the wall

module front_port_windows() {
    z0 = pcb_top_z - 1;
    x0 = ext_x - wall - front_open_x;
    len = wall + front_recess_depth + front_open_x + 2;
    // Ethernet
    translate([x0, pcb_y0 + front_eth_y - eth_cut[0] / 2, z0])
        cube([len, eth_cut[0], eth_cut[1]]);
    // two stacked USB-A
    for (yc = [front_usb1_y, front_usb2_y])
        translate([x0, pcb_y0 + yc - usb_cut[0] / 2, z0])
            cube([len, usb_cut[0], usb_cut[1]]);
}

module front_recess() {
    y_lo = pcb_y0 + front_eth_y - eth_cut[0] / 2 - front_recess_margin;
    y_hi = pcb_y0 + front_usb2_y + usb_cut[0] / 2 + front_recess_margin;
    z_lo = pcb_top_z - 1 - front_recess_margin;
    z_hi = pcb_top_z - 1 + usb_cut[1] + front_recess_margin;
    translate([ext_x - front_recess_depth, y_lo, z_lo])
        cube([front_recess_depth + 1, y_hi - y_lo, z_hi - z_lo]);
}

// ---------------------------------------------------------------------------
// Side port windows (side wall at low Y, the Pi Y=0 edge)
// ---------------------------------------------------------------------------
module side_port_windows() {
    z0 = pcb_top_z - 1;
    ports = [[side_usbc_x, usbc_cut], [side_hdmi0_x, hdmi_cut], [side_hdmi1_x, hdmi_cut]];
    for (p = ports) {
        xc = pcb_x0 + p[0];
        w  = p[1][0];
        h  = p[1][1];
        translate([xc - w / 2, -1, z0])
            cube([w, wall + 2, h]);
    }
}

// ---------------------------------------------------------------------------
// Ventilation over the cooler exhaust (lid + GPIO wall)
// ---------------------------------------------------------------------------
module lid_vents() {
    // slots straight through the lid over the cooler/fan footprint
    n = 7; pitch = 6; slot_w = 2.6; slot_len = 30;
    total = (n - 1) * pitch;
    cx = pcb_x0 + 11 + 63.5 / 2;          // cooler centre X
    translate([cx - total / 2, ext_y / 2 - slot_len / 2, -1])
        vent_slots(n, slot_w, slot_len, pitch, lid_th + 2);
}

module gpio_wall_vents() {
    n = 6; pitch = 6; slot_w = 2.4; slot_len = 14;
    total = (n - 1) * pitch;
    cx = pcb_x0 + 11 + 63.5 / 2;
    translate([cx - total / 2, ext_y - wall - 1, pcb_top_z + 3])
        rotate([-90, 0, 0])
            vent_slots(n, slot_w, slot_len, pitch, wall + 2);
}

// ---------------------------------------------------------------------------
// TRAY
// ---------------------------------------------------------------------------
module tray() {
    difference() {
        union() {
            shell([ext_x, ext_y, tray_h], corner_r, wall, floor_th);
            // Pi standoffs (sunk 0.5 into the floor for a solid weld)
            for (p = pi_hole_xy())
                translate([p[0], p[1], floor_th - 0.5])
                    pcb_standoff(standoff_below + 0.5, boss_d = 8, pilot_d = 2.3);
            // lid screw bosses (heat-set inserts open at the top)
            for (p = boss_xy())
                translate([p[0], p[1], floor_th - 0.5])
                    heatset_boss(tray_h - floor_th + 0.5, boss_d = 7, insert_d = 4.0, insert_depth = 5);
            // accessible multiplexer bay (headers face up; MEASURE the board)
            translate([mux_pos[0], mux_pos[1], floor_th - 0.5])
                component_pocket(31, 21, wall_h = 5.5, wall_t = 2, clearance = 0.4, notch_w = 8);
            // rigid gyro pocket bonded to the floor -> the tamper reference mass
            translate([gyro_pos[0], gyro_pos[1], floor_th - 0.5])
                component_pocket(21, 16, wall_h = 5.5, wall_t = 2, clearance = 0.35,
                                 post_d = 6, post_pilot = 2.6, post_pos = [21 / 2, 16 - 3],
                                 notch_w = 6);
        }
        // Pi mount-hole screw access up through the floor (optional screws)
        for (p = pi_hole_xy())
            translate([p[0], p[1], -1])
                cylinder(h = floor_th + standoff_below + 2, d = 3.0, $fn = cyl_fn);
        front_port_windows();
        front_recess();
        side_port_windows();
        gpio_wall_vents();
    }
}

// ---------------------------------------------------------------------------
// LID  (modelled OUTER-face-down: outer top at z=0, interior grows +Z)
// ---------------------------------------------------------------------------
oled_center = [ext_x - 34, ext_y / 2];    // convenient readable spot on the lid

module lid() {
    difference() {
        union() {
            rounded_box([ext_x, ext_y, lid_th], corner_r);
            // skirt/lip that drops into the tray
            translate([wall + lid_lip_clr, wall + lid_lip_clr, lid_th - eps])
                difference() {
                    rounded_box([interior_x - 2 * lid_lip_clr, interior_y - 2 * lid_lip_clr, lid_lip_h],
                                max(0.1, corner_r - wall));
                    translate([wall, wall, -1])
                        rounded_box([interior_x - 2 * lid_lip_clr - 2 * wall,
                                     interior_y - 2 * lid_lip_clr - 2 * wall, lid_lip_h + 2],
                                    max(0.1, corner_r - 2 * wall));
                }
            translate([oled_center[0], oled_center[1], 0]) oled_pocket_frame(lid_th);
        }
        translate([oled_center[0], oled_center[1], 0]) oled_window_cut(lid_th);
        for (p = boss_xy()) {
            // screw hole (head countersinks into the outer top at z=0)
            translate([p[0], p[1], 0])
                screw_cbore_cut(shank_d = 3.4, head_d = 6.4, head_depth = 2.5);
            // clearance so the drop-in lip does not foul the tray corner bosses
            translate([p[0], p[1], lid_th - eps])
                cylinder(h = lid_lip_h + 1, d = 9, $fn = cyl_fn);
        }
        lid_vents();
    }
}

// ---------------------------------------------------------------------------
// Assembly preview (ghosted Pi + stack for a visual geometry check)
// ---------------------------------------------------------------------------
module ghost_pi() {
    color("green", 0.25) {
        translate([pcb_x0, pcb_y0, pcb_top_z - pcb_th]) cube([pcb_x, pcb_y, pcb_th]);
        translate([pcb_x0 + 11, pcb_y0 + 7, pcb_top_z]) cube([63.5, 42.5, cooler_h]);      // cooler
        translate([pcb_x0 + 10, pcb_y0, pcb_top_z + hat_standoff]) cube([65, 56.5, 3]);    // HAT
        translate([pcb_x0 + 30, pcb_y0 + 17, pcb_top_z + hat_standoff - 3]) cube([80, 22, 2.3]); // SSD
    }
}

module assembly() {
    tray();
    // flip the lid (outer face was down at z=0) and cap the tray with it
    translate([ext_x, 0, ext_z]) rotate([0, 180, 0]) lid();
    %ghost_pi();
}

// ---------------------------------------------------------------------------
// Coupons (fit tests) -- print these before the full parts
// ---------------------------------------------------------------------------
module coupon_front() {
    y_c = pcb_y0 + (front_eth_y + front_usb2_y) / 2;
    intersection() {
        tray();
        translate([ext_x - 32, y_c - 24, -1]) cube([34, 48, tray_h + 2]);
    }
}

module coupon_boss() {
    intersection() {
        tray();
        translate([-1, -1, -1]) cube([boss_inset + 9, boss_inset + 9, tray_h + 2]);
    }
}

// ---------------------------------------------------------------------------
if (render_mode == "tray")              tray();
else if (render_mode == "lid")          lid();
else if (render_mode == "coupon_front") coupon_front();
else if (render_mode == "coupon_boss")  coupon_boss();
else                                    assembly();
