rsp5_x = 56;
rsp5_usb_2_0_pos = 47;
rsp5_usb_3_0_pos = 29.1;
rsp5_eth_pos = 10.2;

base_x = 88;
base_y = 44;
base_z = 2;

base_board_margin = (base_x - rsp5_x) / 2;

usb_x = 16;
usb_y = 16;


eth_x = 17;
eth_y = 14.5;

hole_height = 8;

difference() {
    difference() {
        difference() {
            // base
            cube([base_x,base_y,base_z], false);
            // USB 2.0
            color("black")
            translate([rsp5_usb_2_0_pos - (usb_y / 2) + base_board_margin, hole_height, -1])
            cube([usb_x,usb_y, 10], false);
        };
        // USB 3.0
        color("lightblue")
        translate([rsp5_usb_3_0_pos - (usb_y / 2) + base_board_margin, hole_height, -1])
        cube([usb_x,usb_y, 10], false);
    }
    // Ethernet
    color("red")
    translate([rsp5_eth_pos - (eth_y / 2) + base_board_margin, hole_height, -1])
    cube([eth_x,eth_y, 10], false);
}
