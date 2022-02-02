#!/bin/bash

## ###############
## Variables
## ###############
tempfolder=tmp
binfolder=/usr/local/bin
visudo_path=/private/etc/sudoers.d/battery

# CLI help message
helpmessage="
Battery CLI utility v0.0.2.

Usage: 

  battery status
    output battery SMC status, % and time remaining

  battery charging SETTING
    on: sets CH0B to 00 (allow charging)
    off: sets CH0B to 02 (disallow charging)

  battery charge LEVEL
    LEVEL: percentage to charge to, charging is disabled when percentage is reached.

  battery visudo
    instructions on how to make which utility exempt from sudo

  battery update
    run the installation command again to pull latest version

"

# Visudo instructions
visudoconfig="
# Put this in $visudo_path on a mac

Cmnd_Alias      BATTERYOFF = $binfolder/smc -k CH0B -w 02, $binfolder/smc -k CH0C -w 02
Cmnd_Alias      BATTERYON = $binfolder/smc -k CH0B -w 00, $binfolder/smc -k CH0B -w 00
Cmnd_Alias			UPDATE = $binfolder/battery update
$( whoami ) ALL = NOPASSWD: BATTERYOFF
$( whoami ) ALL = NOPASSWD: BATTERYON
$( whoami ) ALL = NOPASSWD: UPDATE
"

# Get parameters
action=$1
setting=$2

## ###############
## Helpers
## ###############

# Re:charging, Aldente uses CH0B https://github.com/davidwernhart/AlDente/blob/0abfeafbd2232d16116c0fe5a6fbd0acb6f9826b/AlDente/Helper.swift#L227
# but @joelucid uses CH0C https://github.com/davidwernhart/AlDente/issues/52#issuecomment-1019933570
# so I'm using both since with only CH0B I noticed sometimes during sleep it does trigger charging
function enable_charging() {
	echo "$(date +%T) - Enabling battery charging"
	sudo smc -k CH0B -w 00
	sudo smc -k CH0C -w 00
}

function disable_charging() {
	echo "$(date +%T) - Disabling battery charging"
	sudo smc -k CH0B -w 02
	sudo smc -k CH0C -w 02
}

function get_smc_charging_status() {
	hex_status=$( smc -k CH0B -r | awk '{print $4}' | sed s:\):: )
	if [[ "$hex_status" == "02" ]]; then
		echo "disabled"
	else
		echo "enabled"
	fi
}

function get_battery_percentage() {
	battery_percentage=`pmset -g batt | tail -n1 | awk '{print $3}' | sed s:\%\;::`
	echo "$battery_percentage"
}

function get_remaining_time() {
	time_remaining=`pmset -g batt | tail -n1 | awk '{print $5}'`
	echo "$time_remaining"
}

function log() {

	echo -e "$(date +%T) - $1"

}


## ###############
## Actions
## ###############

# Help message 
if [ -z "$action" ]; then
	echo -e "$helpmessage"
	exit 0
fi

# Visudo message
if [[ "$action" == "visudo" ]]; then
	echo -e "This will write the following to $visudo_path:\n"
	echo -e "$visudoconfig"
	echo "If you would like to customise your visodu settings, exit this script and edit the file manually"
	echo -e "\nPress any key to continue\n"
	read
	echo -e "$visudoconfig" | sudo tee $visudo_path
	echo -e "Visudo file $visudo_path now contains: \n"
	sudo cat $visudo_path
	exit 0
fi

# Update helper
if [[ "$action" == "update" ]]; then
	echo "This will run curl -sS https://raw.githubusercontent.com/actuallymentor/battery/main/setup.sh | sudo bash"
	echo "Press any key to continue"
	read
	curl -sS https://raw.githubusercontent.com/actuallymentor/battery/main/setup.sh | sudo bash
	battery
	exit 0
fi


# Charging on/off controller
if [[ "$action" == "charging" ]]; then

	log "Setting $action to $setting"
	
	# Set charging to on and off
	if [[ "$setting" == "on" ]]; then
		enable_charging
	elif [[ "$setting" == "off" ]]; then
		disable_charging
	fi

	exit 0

fi

# Charging on/off controller
if [[ "$action" == "charge" ]]; then

	# Helpful message
	echo -e "Note: you can prevent your mac from sleeping by using the caffeinate built-in utility. Example usage:\ncaffeinate -s battery charge 80"

	# Start charging
	battery_percentage=$( get_battery_percentage )
	log "Charging to $setting% from $battery_percentage%"
	enable_charging

	# Loop until battery percent is exceeded
	while [[ "$battery_percentage" -lt "$setting" ]]; do

		log "Battery at $battery_percentage%"
		sleep 60
		battery_percentage=$( get_battery_percentage )
		
	done

	disable_charging
	log "Charging completed at $battery_percentage%"

	exit 0

fi


# Status logget
if [[ "$action" == "status" ]]; then

	log "Battery at $( get_battery_percentage  )% ($( get_remaining_time ) remaining), smc charging $( get_smc_charging_status )"
	exit 0

fi
