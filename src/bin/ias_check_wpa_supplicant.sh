#!/bin/bash

# NAME
#	ias_check_wpa_supplicant - nagios check for a wireless network
#
# SYNOPSIS
#	ias_check_wpa_supplicant.sh -h for usage
#
# DESCRIPTION
#	This script attempts to, with a given device:
#	* Connect to a wireless network
#	* Get an IP address with dhclient
#	* Returns an appropriate nagios status
#
# Here's an example wpa supplicant config file that I use on my home network:
# network={
#	ssid="SomeSSID"
#	scan_ssid=1
#	key_mgmt=WPA-PSK
#	psk="SuperSecretPassword"
# }
#
# DESIGN GOALS
#	* Not otherwise break networking on the box
#
# USAGE
#	* It must be run as root.
#	* THe device must already be in the "DOWN" state when the script starts.
#
# You'll want Network Manager to be disabled for the interface.
# You can accomplish this by adding the following to Network Manager's
# configuration file:
#
####
#	[main]
#	plugins=keyfile
# 
#	[keyfile]
#	Make sure mac is lower case. Separated by semicolons.
#	unmanaged-devices=mac:c0:ff:ee:c0:ff:ee
####
#
# LICENSE
# copyright (c) 2019 Martin VanWinkle, Institute for Advanced Study
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# DEBUGGING
#	Turn "DEBUG_MESSAGES" to 1.
#

DEBUG_MESSAGES=0

wanted_ip_regex='/24$'
device=""
wpa_supplicant_config="~/.config/IAS/ias-check-wpa-supplicant/wpa_supplicant.conf"
dhclient_config="/etc/dhcp/dhclient.conf"
duration_warning=15
duration_critical=45
stay_connected=0

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. "$DIR/bash_lib.sh"

dhclient_script="${DIR}/dhclient-script"

start_time=$( date +%s )
nagios_service_name="ias-check-wpa-supplicant $device $wpa_supplicant_config"

nagios_status="OK"
nagios_exit="0"

while getopts ":d:c:p:r:s:W:C:D" o; do
	case "${o}" in
		d)
			device="${OPTARG}"
			;;
		c)
			wpa_supplicant_config="${OPTARG}"
			;;
		p)
			dhclient_config="${OPTARG}"
			;;
		r)
			wanted_ip_regex="${OPTARG}"
			;;
		W)
			warning_threshold="${OPTARG}"
			;;
		C)
			critical_threshold="${OPTARG}"
			;;
		D)
			DISPLAY_MESSAGES=1
			;;
		s)
			stay_connected="${OPTARG}"
			;;

		h | *)
			doc_usage
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

if [[ "$DISPLAY_MESSAGES" == "1" ]]
then
	debug_options
fi

if [[ -z "$device" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	doc_usage
	clean_up_and_exit "Error: device not specified."
fi

if [[ $( ip_br_device_exists "$device") != "0" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "ip can't query device $device .  Does it exist?"
fi

if [[ $( ip_br_device_status "$device") != "DOWN" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "$device is not down"
fi

if [[ ! -f "$wpa_supplicant_config" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "Error: wpa_supplicant config file, $wpa_supplicant_config , doesn't exist or is unspecified."
fi

if [[ -z "$wanted_ip_regex" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "Error: you must specify a regular expression for the IP to match."
fi


# Main section

# Flush current IP address(s) from device:

ip addr flush dev "$device"

wpa_pid_file=$(mktemp /tmp/ias-check-wpa-supplicant_wpa_supplicant_pid.XXXXXX)

debug_message "Running wpa_supplicant."
debug_message "wpa_pid_file: $wpa_pid_file"

# q - suppress debugging info
# B - daemonize

trap clean_up_and_exit INT

wpa_supplicant \
	-q \
	-B \
	-i "$device" \
	-c "$wpa_supplicant_config" \
	-P "$wpa_pid_file" \
	> /dev/null

result=$?

if [[ "$result" != "0" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "wpa_supplicant exited with $result"
	exit 3
fi

debug_message "Running dhclient."
# Here, we have a kuldgy work around to dhclient and apparmor.
# If we create a dhclient process with a unique file name
# we can just look it up later using that name and kill the
# pid.  This is referenced to as a "dirty kill".
dhclient_pid_file=$(mktemp /tmp/ias-check-wpa-supplicant_dhclient_pid.XXXXXX)
debug_message "dhclient_pid_file: $dhclient_pid_file"

# 	-sf $dhclient_script \
# ^^ That's what we need to get working in order to not break
# other network config on the box.
dhclient \
	-cf $dhclient_config \
	-pf "$dhclient_pid_file" \
	"$device" &

found_ip=""

for (( c=1; c<=$duration_critical; c++ ))
do  
	sleep 1
	debug_message "Looping. $c"
	
	device_status=$( ip_br_device_status "$device")
	
	if [[ "$device_status" != "UP" ]]
	then
		debug_message "Device $device status: $device_status"
		continue
	fi
	
	found_ip=$( check_for_ip_br_ipv4 "$device" "$wanted_ip_regex")
	result=$?
	debug_message "Found IP: $found_ip"
	debug_message "Result from check_for_ip_br : $result"
	if [[ "$result" == "0" ]]
	then
		clean_up_and_exit "Got ip: $found_ip"
	fi
	
done

nagios_status="CRITICAL"
nagios_exit=2
clean_up_and_exit "TIMEOUT.  IP regex: $wanted_ip_regex . Got IP: $found_ip"
