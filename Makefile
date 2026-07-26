# Build STLs and preview PNGs for the RPi5 CA enclosure.
# Modelled on ../CarcassoneRiver/Makefile: a -D render_mode selector drives the
# single source file into its separate printable parts.

OPENSCAD := /usr/bin/openscad
SRC      := rpi5_ca_case.scad homelab_lib.scad

PARTS    := tray lid coupon_front coupon_boss
STLS     := $(PARTS:%=build/stl/rpi5_ca_%.stl)
PNGS     := $(PARTS:%=build/png/rpi5_ca_%.png) build/png/assembly.png

# oblique preview camera (az, el around the part centre)
CAM_OBL  := --projection=o --imgsize=1000,800 --camera=52,42,22,58,0,28,360

all: $(STLS)
png: $(PNGS)

build/stl/rpi5_ca_%.stl: $(SRC) | build/stl
	$(OPENSCAD) -o $@ -D render_mode=\"$*\" rpi5_ca_case.scad

build/png/rpi5_ca_%.png: $(SRC) | build/png
	$(OPENSCAD) --render -o $@ $(CAM_OBL) -D render_mode=\"$*\" rpi5_ca_case.scad

build/png/assembly.png: $(SRC) | build/png
	$(OPENSCAD) --render -o $@ $(CAM_OBL) -D render_mode=\"assembly\" rpi5_ca_case.scad

build/stl build/png:
	mkdir -p $@

clean:
	rm -rf build/stl build/png

.PHONY: all png clean
