// 1U OLED display rack mount for a 10 inch rack (DeskPi RackMate / GeeekPi)
// Holds 4x ELEGOO 0.96" SSD1306 OLED modules behind window cutouts, screwed
// onto printed bosses from the back. Mounts above the GeeekPi 2U Pi rack mount.
//
// Model orientation = print orientation: front face on the bed (Z = 0), bosses
// and flanges grow upward. The panel is 254mm wide and the MK3 bed is 250mm,
// so rotate the part ~40 degrees around Z in the slicer to fit diagonally.
// No supports needed. PETG or PLA, 4 perimeters.
//
// Before printing the full panel: verify every MEASURE ME value with calipers
// against the actual modules and rack rails, then set render_mode = "coupon"
// and print the small one-display fit test first.

render_mode = "panel"; // "panel" = full faceplate, "coupon" = one-display fit test

cyl_fn = 254;        // resolution for holes
boolean_height = 20; // oversize height for through-cutters

// faceplate
panel_x = 254;  // 10 inch rack faceplate width
panel_y = 43.6; // 1U = 44.45 minus fitting clearance
panel_z = 3;    // faceplate thickness

// rack mounting holes (10 inch rack, EIA-310 pattern)
rack_hole_spacing_x = 236.5;  // horizontal center-to-center // MEASURE ME on the rack rails
rack_hole_spacing_y = 31.75;  // vertical center-to-center, 2 holes per ear
rack_hole_diameter = 6.2;     // clearance for the RackMate M6 rail screws
rack_hole_1_x = (panel_x - rack_hole_spacing_x) / 2;
rack_hole_2_x = panel_x - rack_hole_1_x;
rack_hole_1_y = (panel_y - rack_hole_spacing_y) / 2;
rack_hole_2_y = panel_y - rack_hole_1_y;
rack_rail_width = 17; // back of panel stays flat this far in from each edge so it sits flush on the rails

// ELEGOO 0.96" OLED module (SSD1306, 128x64, I2C)
oled_count = 4;
oled_pitch = 52;            // center-to-center distance between displays
oled_pcb_x = 27.5;          // PCB width  // MEASURE ME
oled_pcb_y = 27.8;          // PCB height // MEASURE ME
oled_hole_spacing_x = 23.5; // mounting hole center-to-center // MEASURE ME
oled_hole_spacing_y = 23.5; // mounting hole center-to-center // MEASURE ME
oled_pilot_diameter = 1.8;  // self-tapping M2 pilot; use 2.5 for M3 screws // MEASURE ME
oled_window_x = 26;         // window cutout: larger than the glass, smaller than the PCB
oled_window_y = 15;
oled_window_offset_y = -2;  // glass center sits below PCB center (pin header at the top)
oled_standoff_z = 2.5;      // boss height: clearance for glass thickness + header solder joints
oled_boss_diameter = 5;
oled_pilot_depth = oled_standoff_z + 1.5; // blind hole, stops 1.5mm short of the front face

// stiffening flanges along top and bottom edges (a 254mm 3mm plate flexes otherwise)
flange_y = 3; // flange wall thickness
flange_z = 6; // rise from the back of the panel
flange_x = panel_x - 2 * rack_rail_width;

oled_center_y = panel_y / 2;
oled_1_center_x = panel_x / 2 - (oled_count - 1) * oled_pitch / 2;
function oled_center_x(i) = oled_1_center_x + i * oled_pitch;

module rack_holes() {
    for (x = [rack_hole_1_x, rack_hole_2_x], y = [rack_hole_1_y, rack_hole_2_y])
        translate([x, y, -1])
            color("red") cylinder(boolean_height, d = rack_hole_diameter, $fn = cyl_fn);
}

module oled_window(center_x) {
    translate([center_x - oled_window_x / 2,
               oled_center_y + oled_window_offset_y - oled_window_y / 2,
               -1])
        color("black") cube([oled_window_x, oled_window_y, boolean_height]);
}

module oled_bosses(center_x) {
    for (dx = [-oled_hole_spacing_x / 2, oled_hole_spacing_x / 2],
         dy = [-oled_hole_spacing_y / 2, oled_hole_spacing_y / 2])
        translate([center_x + dx, oled_center_y + dy, panel_z])
            color("lightblue") cylinder(oled_standoff_z, d = oled_boss_diameter, $fn = cyl_fn);
}

module oled_pilot_holes(center_x) {
    for (dx = [-oled_hole_spacing_x / 2, oled_hole_spacing_x / 2],
         dy = [-oled_hole_spacing_y / 2, oled_hole_spacing_y / 2])
        translate([center_x + dx, oled_center_y + dy,
                   panel_z + oled_standoff_z - oled_pilot_depth])
            color("aqua") cylinder(oled_pilot_depth + 1, d = oled_pilot_diameter, $fn = cyl_fn);
}

module flanges() {
    for (y = [0, panel_y - flange_y])
        translate([rack_rail_width, y, panel_z])
            cube([flange_x, flange_y, flange_z]);
}

module panel_assembly() {
    difference() {
        union() {
            cube([panel_x, panel_y, panel_z]);
            flanges();
            for (i = [0 : oled_count - 1]) oled_bosses(oled_center_x(i));
        }
        rack_holes();
        for (i = [0 : oled_count - 1]) {
            oled_window(oled_center_x(i));
            oled_pilot_holes(oled_center_x(i));
        }
    }
}

if (render_mode == "panel") {
    panel_assembly();
} else {
    // 40mm wide slice around the first display: window, bosses and flange stubs
    intersection() {
        panel_assembly();
        translate([oled_1_center_x - 20, 0, -1])
            cube([40, panel_y, boolean_height]);
    }
}
