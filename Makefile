# Generate the dimensioned drawing for the 10-inch OLED rack panel.

PYTHON ?= python3

all: blueprint

blueprint: oled_display_rack_1u_blueprint.svg

oled_display_rack_1u_blueprint.svg: make_blueprint.py oled_display_rack_1u.scad
	$(PYTHON) make_blueprint.py

.PHONY: all blueprint
