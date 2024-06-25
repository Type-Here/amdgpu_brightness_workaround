#!/bin/bash
#
# =================================== #
#
# APPLY WORKAROUNDS TO FIX BRIGHTNESS AT START-UP
#   -------------
# Original Source: https://wiki.archlinux.org/title/backlight#Backlight_is_always_at_full_brightness_after_a_reboot_with_amdgpu_driver
# This is only a simple interface in order to apply the WA in a simple way.
#   --------------
# Mod by Type-Here
#
# =================================== #


# --- Fix VARIABLES --- #
# NOTE: Brightness variables are set both in systemd and in driver proc (sysy/class/...) and ideally should be equal but meant to be 2 different concepts.

# SystemD BackLight Parameter to be fixed (fix 1)
readonly SYSTEMD_BACKLIGHT_FILE="$(find '/var/lib/systemd/backlight' -name 'pci-*:backlight:amdgpu_bl*')"

# Check and name of systemd backlight service name for amd
readonly DAEMON_BACKLIGHT=$(sudo systemctl --type=service | grep -o 'systemd-backlight@backlight:amdgpu_bl.\.service')

# Path of backlight parameter from AMDGPU Driver
readonly AMDGPU_BACKLIGHT_PATH="$(find /sys/class/backlight -path '*/amdgpu_bl*')"

# Brightness Value in AMDGPU Driver
readonly AMDGPU_BACKLIGHT_FILE="${AMDGPU_BACKLIGHT_PATH}/brightness"

# --- SCRIPT VARIABLES --- #

# FLAG: If No QA is Found is set to 0; 1 = WA nuber 1 is applied; 2 = WA number 2 is applied; //Is Heavily applied in code. Be Careful
WA_USED=0

#Path where we'll create the .sh file to be executed by daemon
USER_SH_PATH="/usr/lib/systemd/system/fixbrightness"

# User Path were Service is Installed - to Be Installed
# ( best place to put system unit files: /etc/systemd/system )
# ( best place to put user unit files /etc/systemd/user or $HOME/.config/systemd/user )
USER_SERVICE_PATH="/usr/lib/systemd/system"

# Fix Name Applied
FIX_NAME=""

# Service Name Applied
SERVICE_NAME=""

# Removes (All) WorkAround(s) ---- Used also by 5 or r Menu Choice to remove without subsitute WA
clean_old_wa(){

	# Additional Check on Call
	if [ $WA_USED -eq 0 ]; then
		echo "ERROR: I should not never be here. No WA Found. Exiting";
		exit 1;
	fi

	# Disabling Service First
	sudo systemctl disable fix_brightness${WA_USED}.service

	# Removing .sh and .service
	if ! sudo rm -f "${USER_SH_PATH}/fix"*.sh ; then
		echo "Error Removing sh.";
		exit 1;
	fi

	if ! sudo rm -f "${USER_SERVICE_PATH}/fix_brightness"*.service; then
		echo "Error Removing service.";
		exit 1;
	fi

	# Reloading systemctl
	sudo systemctl daemon-reload

	echo "Done."
}


# Checks for Old WorkArounds, $1 = parameter passed to function!
check_old_wa(){
	if [ "${WA_USED}" -gt 0 ]; then
		if [ "${WA_USED}" -eq "$1" ]; then APPLQUERY="reapply it";
		else APPLQUERY="remove fix${WA_USED}.service and apply new fix"
		fi
		read -n 3 -r -p "REQUEST: Workaround n°${WA_USED} is already on; Would you like tou ${APPLQUERY}? (y/N) " response
		case $response in
			[yY] | [yY][eE][sS] ) echo "Cleaning old Workaround... "; clean_old_wa;;
			*) echo "OK. Exiting..."; exit 0;;
		esac
	fi
}


## -------    Applies FIRST FIX: 16 -> 8 Bits Brightness Value   -------- ##
launch_first(){
    echo -e "\n ----- First WA Selected. ----- \n"

	# name and complete path of file .sh
    FIX_NAME="fix1";
    FIX_FILE="${USER_SH_PATH}/${FIX_NAME}.sh"

	# name and complete path of file .service
    SERVICE_NAME="fix_brightness1.service"
    SERVICE_FILE="${USER_SERVICE_PATH}/${SERVICE_NAME}"

	# Create a Dir for FIX in USER_SH_PATH
    sudo mkdir -p "$USER_SH_PATH";

    # Make a void fix1.sh file
    sudo touch "${FIX_FILE}";

    echo "Checking Variable to be set from: "
    echo "$SYSTEMD_BACKLIGHT_FILE";

    # Creating .sh file to be executed by service to cut the 16 bits value to 8 bits
    echo -e "\n# Creating .sh file to be executed by service to cut the 16 bits value to 8 bits..."
    sudo tee "${FIX_FILE}" > /dev/null <<-EOT
		#!/bin/bash

		# Apply this fix for brightness amdgpu driver bug. Source ArchWiki.
		# Implemented by Type-here's bright_wa.sh

		#From 16 bit to # 8 bit brightness value
		BRIGHTNESS_FILE="${SYSTEMD_BACKLIGHT_FILE}"
		BRIGHTNESS="\$(cat "\${BRIGHTNESS_FILE}" )"
		BRIGHTNESS=\$((\$BRIGHTNESS*255/65535))
		BRIGHTNESS=\${BRIGHTNESS/.*} # truncating to int, just in case
		echo "\$BRIGHTNESS" > "\${BRIGHTNESS_FILE}"

		# Add from bright_wa.sh (type-here)
		# Addition for ensuring new value is set in driver param (brightness value)
		echo "\$BRIGHTNESS" > "${AMDGPU_BACKLIGHT_FILE}"
	EOT

	if [ $? -gt 0 ]; then
		>&2 echo "Error Writing to SH File. Exiting!"
		exit 1;
	fi

	sudo chmod u+x "${FIX_FILE}"

    # Creating Daemon file for systemd
    echo -e "\n# Creating Daemon .service file..."
    sudo touch "${SERVICE_FILE}"
    sudo tee "${SERVICE_FILE}" > /dev/null <<-EOT

		# Service for Fixing AmdGPU Driver Bug for Brightness
		[Unit]
		Description=Convert 16-bit brightness values to 8-bit before systemd-backlight applies it
		Before=${DAEMON_BACKLIGHT}

		[Service]
		Type=oneshot
		ExecStart="${FIX_FILE}"

		[Install]
		WantedBy=multi-user.target
	EOT

	if [ $? -gt 0 ]; then
		>&2 echo "Error Writing Service File. Exiting!"
		exit 1;
	fi

	# Verify new unit systemd file
	sudo systemd-analyze verify "${SERVICE_FILE}"

	# Reload systemctl source list
	sudo systemctl daemon-reload
	# sudo systemctl unmask "${SERVICE_NAME}"

	# Enable new fix service
	if ! sudo systemctl enable --now ${SERVICE_NAME} ; then
		>&2 echo "Error Enabling Service. Exiting!"
		exit 1;
	fi

	echo " --- "
    echo "Fix Applied! Exiting..."

    exit 0;

}

## ---------  SECOND FIX: Save Brightness state before shutdown to prevent kernel race bug  ---------- ##
launch_second(){
    echo -e "\n ----- Second WA Selected. ----- \n"

	# name and complete path of file .sh
    FIX_NAME="fix2";
    FIX_FILE="${USER_SH_PATH}/${FIX_NAME}.sh"

	# name and complete path of file .service
    SERVICE_NAME="fix_brightness2.service"
    SERVICE_FILE="${USER_SERVICE_PATH}/${SERVICE_NAME}"

    # Create a Dir for FIX in USER_SH_PATH
    sudo mkdir -p "$USER_SH_PATH";

    # Make a void fix1.sh file
    sudo touch "${FIX_FILE}";

    echo "Checking Variable to be set from: "
    echo "$SYSTEMD_BACKLIGHT_FILE";

    # Creating .sh file to be executed by service to cut the 16 bits value to 8 bits
    echo -e "\n# Creating .sh file to be executed by service to fix kernel reace bug..."
    sudo tee "${FIX_FILE}" > /dev/null <<-EOT
		#!/bin/bash
		# Backlight level from systemd's perspective (change if needed)
		readonly SYSTEMD_BACKLIGHT_FILE="${SYSTEMD_BACKLIGHT_FILE}"

		# Backlight level from AMDGPU driver
		readonly AMDGPU_BACKLIGHT_FILE="${AMDGPU_BACKLIGHT_FILE}"

		# Read current value from the driver and apply it to systemd
		readonly AMDGPU_BACKLIGHT_VALUE=\$(cat "\$AMDGPU_BACKLIGHT_FILE")
		echo "\$AMDGPU_BACKLIGHT_VALUE" > "\$SYSTEMD_BACKLIGHT_FILE"
	EOT

	if [ $? -gt 0 ]; then
		>&2 echo "Error Writing to SH File. Exiting!"
		exit 1;
	fi

	# Make .sh executable
	sudo chmod u+x "${FIX_FILE}"

    # Creating Daemon file for systemd
    echo -e "\n# Creating Daemon .service file..."
    sudo touch "${SERVICE_FILE}"
    sudo tee "${SERVICE_FILE}" > /dev/null <<-EOT

		# Service for Fixing AmdGPU Driver Bug for Brightness Fix 2
		[Unit]
		Description=Save brightness value from AMDGPU
		DefaultDependencies=no
		After=final.target

		[Service]
		Type=oneshot
		ExecStart="${FIX_FILE}"

		[Install]
		WantedBy=final.target

	EOT

	if [ $? -gt 0 ]; then
		>&2 echo "Error Writing Service File. Exiting!"
		exit 1;
	fi

	# Verify new unit systemd file
	sudo systemd-analyze verify "${SERVICE_FILE}"

	# Reload systemctl source list
	sudo systemctl daemon-reload
	# sudo systemctl unmask "${SERVICE_NAME}"

	# Enable new fix service
	if ! sudo systemctl enable --now ${SERVICE_NAME} ; then
		>&2 echo "Error Enabling Service. Exiting!"
		exit 1;
	fi

	echo " --- "
    echo "Fix Applied! Exiting..."

	exit 0;

}


#
## ---------   MAIN   --------- ##
#

echo -e "\n -- | WELCOME | -- \n"

IS_AMDGPU="$(sudo lspci -v | grep -A 10 -i vga | grep -o AMD)"
IS_AMGPU_DRIVER="$(sudo lspci -v | grep -A 30 -i vga | grep -o amdgpu | head -n 1)"

echo "Checking for requirements... "
# Look for AMD GPU
if [[ $IS_AMDGPU != 'AMD' ]]; then
	echo "ERROR: No AMD Gpu Found. VGA Controllers Showed to Check. For more info use lscpi or others: "
	lspci -v | grep -A 30 -i vga ;
	echo -e "\n\n Exiting..."

	exit 1;
else
	echo "- AMD CPU Found. "
fi

# Look for amdgpu driver

if [[ $IS_AMGPU_DRIVER != 'amdgpu' ]]; then
	echo "ERROR: AMD Gpu Found but amdgpu driver is not in use. Extract of lspci output here:"
	lspci -v | grep -A 30 -i vga ;
	echo -e "\n\n Exiting..."

	exit 1;
else
	echo "- amdgpu driver found."
fi

if lsmod | grep -q amdgpu; then
    echo -e "- amdgpu kernel module is loaded.\n"
else
    echo "ERROR: amdgpu kernel module is not loaded. Check your driver installation."
    exit 1;
fi


IS_AMDGPU_BACKLIGHT="$(find '/var/lib/systemd/backlight' -name 'pci-*:backlight:amdgpu_bl*' | wc --lines)"

# Look for backlight variable in systemd directory
if [ "$IS_AMDGPU_BACKLIGHT" -eq 0 ]; then
	echo -e "No AMDGPU_BACKLIGHT var found in var/lib/systemd/backlight."
	echo -e "\n\tIt looks like you have an amd gpu with 'amdgpu' driver in use but no var for backlight found in systemd."
	echo -e "\nExiting...\n";
	exit 1;

elif [ "$IS_AMDGPU_BACKLIGHT" -ge 2 ]; then
    echo -e "More than 1 display was found. \nTry removing eventual external monitors or bypass this check in code. \nExiting..."
    exit 1;
fi

echo "Printing some variables, just in case: "
echo "$SYSTEMD_BACKLIGHT_FILE"
echo "$AMDGPU_BACKLIGHT_FILE"
echo -e " --- \n"

if [[ -d "$USER_SH_PATH" ]]; then
    if [[ -f "${USER_SERVICE_PATH}/fix_brightness1.service" ]]; then
        echo "INFO: WA 1 Already Found."
        WA_USED=1;
    elif [[ -f "${USER_SERVICE_PATH}/fix_brightness2.service" ]]; then
        echo "INFO: WA 2 Already Found."
        WA_USED=2;
    fi
else
    echo -e "Primo Utilizzo: \n"
fi

echo -e "\n-- Set a WorkAround for Brightness Bug at Startup --\n"
echo -e " 1. Set stored brightness to within the correct range (16-bit to 8-bit int); (Default)
         \n 2. Save the brightness level to systemd before shutting down (Race in Kernel Bug);
         \n 5. or 'R' Remove Applied WorkAround;
         \n 0. Press 0 or q to exit."
echo -e "\nThe suggested approach is to try the First bugfix first. \nIf it doesn't work, relaunch the sh and try the second. \nOlder WA Files will be eliminated automatically.\n"

read -n 3 -r -p "- What Workaround would you like to use? (1-2) (5 o R to rem) " response
case $response in
    "1") check_old_wa "$response"; launch_first;;
    "2") check_old_wa "$response"; launch_second;;

    ## ---------- Removing WorkArounds by Choice ---- ##
    "5" | [rR] ) echo -e "\n ----- Removing All WorkArounds ----- \n";  clean_old_wa "$WA_USED"; exit 0;;

    [qQ] | [0] | [nN] ) echo "Exiting..."; exit 0;;

    *) echo "No Valid Choice Made. Exiting..."; exit 0;;
esac

exit 0;
#
