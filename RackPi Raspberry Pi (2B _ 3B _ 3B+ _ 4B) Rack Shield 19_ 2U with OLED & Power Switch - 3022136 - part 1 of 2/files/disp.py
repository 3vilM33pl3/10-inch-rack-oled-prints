#!/usr/bin/env python
import time
import Adafruit_GPIO.SPI as SPI
import Adafruit_SSD1306
import RPi.GPIO as GPIO
import subprocess

from PIL import Image
from PIL import ImageDraw
from PIL import ImageFont

GPIO.setmode(GPIO.BCM)
GPIO.setup(23, GPIO.OUT)
GPIO.setup(20, GPIO.IN)

DISP_OFF = 0xAE

# Raspberry Pi pin configuration:
INFO_BTN = 20
LED = 23
RST = None

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

# 128x32 display with hardware I2C:
disp = Adafruit_SSD1306.SSD1306_128_32(rst=RST)

# Initialize library.
disp.begin()

# Clear display.
disp.clear()
disp.display()

# Create blank image for drawing.
# Make sure to create image with mode '1' for 1-bit color.
width = disp.width
height = disp.height
image = Image.new('1', (width, height))

# Get drawing object to draw on image.
draw = ImageDraw.Draw(image)

# Draw a black filled box to clear the image.
draw.rectangle((0,0,width,height), outline=0, fill=0)

# Draw some shapes.
# First define some constants to allow easy resizing of shapes.
padding = -2
top = padding
bottom = height-padding
# Move left to right keeping track of the current x position for drawing shapes.
x = 0

# Load default font.
font = ImageFont.load_default()

# Alternatively load a TTF font.  Make sure the .ttf font file is in the same directory as the python script!
# Some other nice fonts to try: http://www.dafont.com/bitmap.php
# font = ImageFont.truetype('Minecraftia.ttf', 8)

GPIO.output(LED, GPIO.HIGH)

# Startup Info
draw.rectangle((0,0,width,height), outline=0, fill=0)
draw.text((x, top),    "--------------------", font=font, fill=255)
draw.text((x, top+12), " Infoscreen Started ", font=font, fill=255)
draw.text((x, top+24), "--------------------", font=font, fill=255)
disp.image(image)
disp.display()

time.sleep(5)

while True:

    # Draw a black filled box to clear the image.
    draw.rectangle((0,0,width,height), outline=0, fill=0)

    # Info Button pressed?
    if GPIO.input(INFO_BTN) == 0:
        if disp_timer == 0:
            disp.begin()
        if menu_timer >= REBOOT_TIMEOUT:
            menu_state = 1
        if menu_timer >= SHUTDOWN_TIMEOUT:
            menu_state = 2
        disp_timer = DISP_TIMEOUT
        menu_timer = menu_timer+1
    elif disp_timer == 0:
        disp.image(image)
        disp.display()
        disp.command(DISP_OFF)


    if disp_timer > 0:

        if menu_state == 0:
            # Shell scripts for system monitoring from here : https://unix.stackexchange.com/questions/119126/command-to-display-memory-usage-disk-usage-and-cpu-load
            cmd = "hostname"
            HOSTNAME =  subprocess.check_output(cmd, shell = True)
            cmd = "hostname -I | cut -d\' \' -f1"
            IP = subprocess.check_output(cmd, shell = True )
            cmd = "top -bn1 | grep load | awk '{printf \"CPU: %3d%%\", $(NF-2)*100/4}'"
            CPU = subprocess.check_output(cmd, shell = True )
            cmd = "free -m | awk 'NR==2{printf \"MEM: %3d%%\", $3*100/$2 }'"
            MemUsage = subprocess.check_output(cmd, shell = True )
            # cmd = "df -h | awk '$NF==\"/\"{printf \"Disk: %d/%dGB %s\", $3,$2,$5}'"
            # Disk = subprocess.check_output(cmd, shell = True )

            # Write two lines of text.

            draw.text((x, top),       "NAME: " + HOSTNAME, font=font, fill=255)
            draw.text((x, top+12),    "IP  : " + str(IP),  font=font, fill=255)
            draw.text((x, top+24),    str(CPU) + " | " + str(MemUsage), font=font, fill=255)
            # draw.text((x, top+27),    str(MemUsage),  font=font, fill=255)
            # draw.text((x, top+25),    str(Disk),  font=font, fill=255)
            disp_timer =  disp_timer-1

            if GPIO.input(INFO_BTN) == 1:
                menu_timer = 0

        if menu_state == 1:
            if GPIO.input(INFO_BTN) == 1:
                do_reboot = 1
                draw.text((x, top+12), "Performing Reboot...", font=font, fill=255)
                disp.image(image)
                disp.display()
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
                disp.display()
                time.sleep(3)
                draw.rectangle((0,0,width,height), outline=0, fill=0)
            else:
                draw.text((x, top),    "......Shutdown......"     , font=font, fill=255)
                draw.text((x, top+12), "   Release Button   "   , font=font, fill=255)
                draw.text((x, top+24), "    To Shutdown     "      , font=font, fill=255)

        disp.image(image)
        disp.display()

        if do_reboot == 1:
            cmd = "sudo reboot now"
            subprocess.Popen(cmd, shell = True)
        if do_shutdown == 1:
            cmd = "sudo shutdown now"
            subprocess.Popen(cmd, shell = True)
        time.sleep(1)
