rsp5_x = 56;
rsp5_usb_1_pos = 47;
rsp5_usb_2_pos = 29;
rsp5_eth_pos = 10.25;

base_x = 85;
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
            cube([base_x,base_y,base_z], false);
            color("aqua")
            translate([rsp5_usb_1_pos - (usb_y / 2) + base_board_margin, hole_height, -1])
            cube([usb_x,usb_y, 10], false);
        };
        color("aqua")
        translate([rsp5_usb_2_pos - (usb_y / 2) + base_board_margin, hole_height, -1])
        cube([usb_x,usb_y, 10], false);
    }
    color("aqua")
    translate([rsp5_eth_pos - (eth_y / 2) + base_board_margin, hole_height, -1])
    cube([eth_x,eth_y, 10], false);
}
