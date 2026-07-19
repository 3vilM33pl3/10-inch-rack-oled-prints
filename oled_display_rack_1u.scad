// 1U OLED display rack mount for a 10 inch rack (DeskPi RackMate / GeeekPi)
// Holds 4x ELEGOO 0.96" SSD1306 OLED modules in screwless drop-in pockets
// behind window cutouts. Each module drops into its pocket from the back and
// is held with tape (Kapton/electrical) across the pocket wall tops, which
// also covers and protects the electronics. Mounts above the GeeekPi 2U Pi
// rack mount. Header pins point backward; jumper wires exit through the gap
// in the top wall of each pocket.
//
// Model orientation = print orientation: front face on the bed (Z = 0),
// pocket walls and flanges grow upward. The panel is 254mm wide and the MK3
// bed is 250mm, so rotate the part ~40 degrees around Z in the slicer to fit
// diagonally. No supports needed. PETG or PLA, 4 perimeters.
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
oled_window_x = 26;         // window cutout: larger than the glass, smaller than the PCB
oled_window_y = 15;
oled_window_offset_y = -2;  // glass center sits below PCB center (pin header at the top)

// drop-in pocket: module sits in a raised frame on the back, held by tape
oled_pocket_clearance = 0.25;  // per side; easy drop-in fit, tape does the holding
oled_pocket_x = oled_pcb_x + 2 * oled_pocket_clearance;
oled_pocket_y = oled_pcb_y + 2 * oled_pocket_clearance;
oled_wall_xy = 2.4;            // pocket wall thickness
oled_wall_z = 4;               // wall rise above panel back; PCB + back components end up ~flush
oled_wire_gap_x = 16;          // opening in the top wall for the 4 backward pins / Dupont plugs
oled_notch_y = 8;              // fingernail gaps in the side walls to lift a module out

// shallow groove in the panel back where the header solder fillets bulge on the
// PCB front, so the module still sits flat with the glass nosing into the window
oled_solder_relief_depth = 1.2; // MEASURE ME - fillet height on the PCB front
oled_solder_relief_y = 6;       // groove height, measured down from the pocket top edge

// stiffening flanges along top and bottom edges (a 254mm 3mm plate flexes otherwise)
flange_y = 3; // flange wall thickness
flange_z = 6; // rise from the back of the panel

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

// groove cut into the back face of the panel across the header solder row
module oled_solder_relief(center_x) {
    translate([center_x - oled_pocket_x / 2,
               oled_center_y + oled_pocket_y / 2 - oled_solder_relief_y,
               panel_z - oled_solder_relief_depth])
        color("aqua") cube([oled_pocket_x, oled_solder_relief_y, oled_solder_relief_depth + 1]);
}

// rectangular pocket frame on the panel back, with a wire gap in the top wall
// and removal notches in the side walls
module oled_pocket_frame(center_x) {
    frame_x = oled_pocket_x + 2 * oled_wall_xy;
    frame_y = oled_pocket_y + 2 * oled_wall_xy;
    difference() {
        translate([center_x - frame_x / 2, oled_center_y - frame_y / 2, panel_z])
            color("lightblue") cube([frame_x, frame_y, oled_wall_z]);
        // pocket opening
        translate([center_x - oled_pocket_x / 2, oled_center_y - oled_pocket_y / 2, panel_z - 1])
            color("black") cube([oled_pocket_x, oled_pocket_y, oled_wall_z + 2]);
        // wire gap in the top wall
        translate([center_x - oled_wire_gap_x / 2, oled_center_y + oled_pocket_y / 2 - 1, panel_z - 1])
            color("red") cube([oled_wire_gap_x, oled_wall_xy + 2, oled_wall_z + 2]);
        // removal notches in the left and right walls
        for (side = [-1, 1])
            translate([center_x + side * (oled_pocket_x / 2 + oled_wall_xy / 2) - oled_wall_xy / 2 - 1,
                       oled_center_y - oled_notch_y / 2,
                       panel_z - 1])
                color("red") cube([oled_wall_xy + 2, oled_notch_y, oled_wall_z + 2]);
    }
}

module flanges() {
    flange_x = panel_x - 2 * rack_rail_width;
    for (y = [0, panel_y - flange_y])
        translate([rack_rail_width, y, panel_z])
            cube([flange_x, flange_y, flange_z]);
}

module panel_assembly() {
    difference() {
        union() {
            cube([panel_x, panel_y, panel_z]);
            flanges();
            for (i = [0 : oled_count - 1]) oled_pocket_frame(oled_center_x(i));
        }
        rack_holes();
        for (i = [0 : oled_count - 1]) {
            oled_window(oled_center_x(i));
            oled_solder_relief(oled_center_x(i));
        }
    }
}

if (render_mode == "panel") {
    panel_assembly();
} else {
    // 40mm wide slice around the first display: window, pocket and flange stubs
    intersection() {
        panel_assembly();
        translate([oled_1_center_x - 20, 0, -1])
            cube([40, panel_y, boolean_height]);
    }
}
