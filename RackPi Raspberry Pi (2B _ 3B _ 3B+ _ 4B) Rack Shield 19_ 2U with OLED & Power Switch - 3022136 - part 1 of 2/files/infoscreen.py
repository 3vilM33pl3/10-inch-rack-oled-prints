# Copyright (c) 2017 Adafruit Industries
# Author: Tony DiCola & James DeVito
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


# This example is for use on (Linux) computers that are using CPython with
# Adafruit Blinka to support CircuitPython libraries. CircuitPython does
# not support PIL/pillow (python imaging library)!

import time
import subprocess

from board import SCL, SDA
import busio
import RPi.GPIO as GPIO
from PIL import Image, ImageDraw, ImageFont
import adafruit_ssd1306
import psutil

GPIO.setmode(GPIO.BCM)
GPIO.setup(23, GPIO.OUT)
GPIO.setup(20, GPIO.IN)

DISP_OFF = 0xAE

# Raspberry Pi pin configuration:
INFO_BTN = 20
LED = 23

# Timer for Display timeout
disp_timer = 0
DISP_TIMEOUT = 15

# Menu Variables
menu_state = 0 # 0 = Info; 1 = Reboot; 2 = Restart
menu_timer = 0
REBOOT_TIMEOUT = 5
SHUTDOWN_TIMEOUT = 10

do_reboot = 0
do_shutdown = 0

# Create the I2C interface.
i2c = busio.I2C(SCL, SDA)

# Create the SSD1306 OLED class.
# The first two parameters are the pixel width and pixel height.  Change these
# to the right size for your display!
disp = adafruit_ssd1306.SSD1306_I2C(128, 32, i2c)

# Clear display.
disp.rotation = 2
disp.fill(0)
disp.show()

# Create blank image for drawing.
# Make sure to create image with mode '1' for 1-bit color.
width = disp.width
height = disp.height
image = Image.new("1", (width, height))

# Get drawing object to draw on image.
draw = ImageDraw.Draw(image)

# Draw a black filled box to clear the image.
draw.rectangle((0, 0, width, height), outline=0, fill=0)

# Draw some shapes.
# First define some constants to allow easy resizing of shapes.
padding = -2
top = padding
bottom = height - padding
# Move left to right keeping track of the current x position for drawing shapes.
x = 0


# Load default font.
font = ImageFont.load_default()

# Alternatively load a TTF font.  Make sure the .ttf font file is in the
# same directory as the python script!
# Some other nice fonts to try: http://www.dafont.com/bitmap.php
# font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 9)

GPIO.output(LED, GPIO.HIGH)

# Startup Info
draw.rectangle((0,0,width,height), outline=0, fill=0)
draw.text((x, top),    "--------------------", font=font, fill=255)
draw.text((x, top+12), " Infoscreen Started ", font=font, fill=255)
draw.text((x, top+24), "--------------------", font=font, fill=255)
disp.image(image)
disp.show()

time.sleep(5)

while True:

    # Draw a black filled box to clear the image.
    draw.rectangle((0, 0, width, height), outline=0, fill=0)
    
    # Info Button pressed?
    if GPIO.input(INFO_BTN) == 0:
        #if disp_timer == 0:
            # disp.begin()
        if menu_timer >= REBOOT_TIMEOUT:
            menu_state = 1
        if menu_timer >= SHUTDOWN_TIMEOUT:
            menu_state = 2
        disp_timer = DISP_TIMEOUT
        menu_timer = menu_timer+1
    elif disp_timer == 0:
        disp.image(image)
        disp.show()
        # disp.poweroff()
    
    if disp_timer > 0:

        if menu_state == 0:
            # Shell scripts for system monitoring from here : https://unix.stackexchange.com/questions/119126/command-to-display-memory-usage-disk-usage-and-cpu-load
            cmd = "hostname"
            HOSTNAME =  subprocess.check_output(cmd, shell = True)
            cmd = "hostname -I | cut -d\' \' -f1"
            IP = subprocess.check_output(cmd, shell = True )
            
            # Examples of getting system information from psutil : https://www.thepythoncode.com/article/get-hardware-system-information-python#CPU_info
            CPU = "{:3.0f}".format(psutil.cpu_percent())
            svmem = psutil.virtual_memory()
            MemUsage = "{:2.0f}".format(svmem.percent)

            draw.text((x, top),       "NAME: " + HOSTNAME.decode('UTF-8'), font=font, fill=255)
            draw.text((x, top+12),    "IP  : " + IP.decode('UTF-8'),  font=font, fill=255)
            draw.text((x, top+24),    "CPU : " + CPU + "% | MEM: " + MemUsage + "%", font=font, fill=255)
            
            disp_timer =  disp_timer-1

            if GPIO.input(INFO_BTN) == 1:
                menu_timer = 0

        if menu_state == 1:
            if GPIO.input(INFO_BTN) == 1:
                do_reboot = 1
                draw.text((x, top+12), "Performing Reboot...", font=font, fill=255)
                disp.image(image)
                disp.show()
                time.sleep(3)
                draw.rectangle((0,0,width,height), outline=0, fill=0)
            else:
                draw.text((x, top),    ".......Reboot......."     , font=font, fill=255)
                draw.text((x, top+12), "   Release Button   "   , font=font, fill=255)
                draw.text((x, top+24), "      To Reboot     "    , font=font, fill=255)

        if menu_state == 2:
            if GPIO.input(INFO_BTN) == 1:
                do_shutdown = 1
                draw.text((x, top+12), "Shutting down.......", font=font, fill=255)
                disp.image(image)
                disp.show()
                time.sleep(3)
                draw.rectangle((0,0,width,height), outline=0, fill=0)
            else:
                draw.text((x, top),    "......Shutdown......"     , font=font, fill=255)
                draw.text((x, top+12), "   Release Button   "   , font=font, fill=255)
                draw.text((x, top+24), "    To Shutdown     "      , font=font, fill=255)

        disp.image(image)
        disp.show()

        if do_reboot == 1:
            cmd = "sudo reboot now"
            subprocess.Popen(cmd, shell = True)
        if do_shutdown == 1:
            cmd = "sudo shutdown now"
            subprocess.Popen(cmd, shell = True)
        time.sleep(1)
