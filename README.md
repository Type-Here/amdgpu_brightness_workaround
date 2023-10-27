# AMDgpu Brightness Workaround
From [ArchWiki](https://wiki.archlinux.org/title/backlight#Backlight_is_always_at_full_brightness_after_a_reboot_with_amdgpu_driver) for source and codefix.  
This repo provides only a nicer and semiautomatic implementation.

This code *should* work on any Linux machine presenting the issue with AMDGPU Driver in use.

### Fix 1
Why?
>Due to a bug introduced recently in the amdgpu driver, the backlight's actual_brightness value is reported as a 16-bit integer, which is outside the 8-bit range specified in max_brightness. 
>This causes the systemd-backlight service to attempt to restore, at boot time, a value that is too large and ends being truncated to maximum brightness (255). 

This should be your first try. It converts 16-bit brightness values to 8-bit before systemd-backlight applies it

### Fix 2
Why?
>On certain systems, the backlight level reported by the driver is in the correct range [0, 255], but systemd still fails to restore the correct value. 
>This is probably due to a race in the kernel. 

In this case, truncating the brightness level will not help since it is already in the correct range. 
Instead, saving the brightness level to systemd before shutting down could work as a workaround.

### Usage
- Download: bright_wa.sh
- Navigate to the folder were the script is downloaded
- Run `sudo chmod u+x bright_wa.sh`
- Run the script: `./bright_wa.sh`
- Follow the instruction in the cli.
- Enjoy. (I hope)

### Script Menu and Options 
Choices are available when running the script. No parameters yet.

When prompted, choice among:  

    1. Set stored brightness to within the correct range (16-bit to 8-bit int); (Preferred)  
    2. Save the brightness level to systemd before shutting down (Race in Kernel Bug);  
    5. or 'R' Remove Applied Workaround(s);  
    0. Press 0 or q to exit.  

    The suggested approach is to try the First Bugfix first. 
    If it doesn't work, relaunch the sh and try the second. 

    Older workaround files will be eliminated automatically when applying.

### Thanks
Thanks to the Arch community.

#### Issues
If you encounter any issues or have any suggestions please contact me.

#### No Warranty
Released 'As Is'. No responsibility for any issues.

