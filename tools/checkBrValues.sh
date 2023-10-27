#!/bin/bash

echo -e "# Driver Values: \nBrightness: " > values.txt
cat /sys/class/backlight/amdgpu_bl1/brightness >> values.txt

echo -e "actual_brightness" >> values.txt
cat /sys/class/backlight/amdgpu_bl1/actual_brightness >> values.txt

echo -e "\n# Kernel Values: \nBrightness: " >> values.txt
cat /var/lib/systemd/backlight/pci-0000\:03\:00.0\:backlight\:amdgpu_bl1 >> values.txt

exit 0;
