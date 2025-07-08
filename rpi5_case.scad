rsp5_x = 56;
rsp5_usb_2_0_pos = 47;
rsp5_usb_3_0_pos = 29.1;
rsp5_eth_pos = 10.2;

boolean_height = 10;
boolean_offset = -1;

base_x = 88;
base_y = 44;
base_z = 2;

base_screw_pos_y = base_y / 2;
base_screw_1_pos_x = 6;
base_screw_2_pos_x = base_x - base_screw_1_pos_x;
base_screw_hole_radius = 4.5 / 2;

base_board_margin = (base_x - rsp5_x) / 2;

usb_x = 16;
usb_y = 16;


eth_x = 17;
eth_y = 14.5;

hole_y_offset = 8;

difference() {
    difference() {
        difference() {
            difference() {
                // base
                cube([base_x,base_y,base_z], false);
                // USB 2.0
                color("black")
                translate([rsp5_usb_2_0_pos - (usb_y / 2) + base_board_margin, hole_y_offset, -1])
                cube([usb_x,usb_y, boolean_height], false);
            };
            // USB 3.0
            color("lightblue")
            translate([rsp5_usb_3_0_pos - (usb_y / 2) + base_board_margin, hole_y_offset, -1])
            cube([usb_x,usb_y, boolean_height], false);
        }
        // Ethernet
        color("red")
        translate([rsp5_eth_pos - (eth_y / 2) + base_board_margin, hole_y_offset, -1])
        cube([eth_x,eth_y, boolean_height], false);
    }

    {
        translate([base_screw_1_pos_x, base_screw_pos_y, -1])
        cylinder(boolean_height, base_screw_hole_radius, base_screw_hole_radius, $fn=254);

        translate([base_screw_2_pos_x, base_screw_pos_y, -1])
        cylinder(boolean_height, base_screw_hole_radius, base_screw_hole_radius, $fn=254);
    }
}