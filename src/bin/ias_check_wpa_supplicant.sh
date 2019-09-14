#!/bin/bash

device="$1"; shift
config="$1"; shift;
wanted_ip_regex="$1"

# NAME
#	ias_check_wpa_supplicant - nagios check for a wireless network
#
# SYNOPSIS
#	ias_check_wpa_supplicant.sh device wpa_supplicant_config wanted_ip_regex
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
##
#	[main]
#	plugins=keyfile
# 
#	[keyfile]
#	Make sure mac is lower case. Separated by semicolons.
#	unmanaged-devices=mac:c0:ff:ee:c0:ff:ee
##
#
# DEBUGGING
#	Turn "DEBUG_MESSAGES" to 1.
#
# TODO / ISSUES(?)
# I have in my notes to add the device to /etc/network/interfaces
# I don't know if that's necessary any more.

DEBUG_MESSAGES=0

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. "$DIR/bash_lib.sh"

start_time=$( date +%s )
nagios_service_name="ias_check_wpa_supplicant $device $config"

nagios_status="OK"
nagios_exit="0"

# Prep section
# ip_exists=$( ip_br_device_exists "$device")
# debug_message "IP exists: $ip_exists"

function usage
{
	echo "Usage: $0 device config ip_regex"
}

if [[ -z "$device" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "Error: device not specified. $( usage )"
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

if [[ ! -f "$config" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "Error: config file doesn't exist or is unspecified."
fi

if [[ -z "$wanted_ip_regex" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "Error: you must specify what IP you will be given."
fi


# Main section

# Flush current IP address(s) from device:

ip addr flush dev "$device"

wpa_pid_file=$(mktemp /tmp/ias_check_wpa_supplicant-wpa_supplicant_pid.XXXXXX)

debug_message "Running wpa_supplicant."
debug_message "wpa_pid_file: $wpa_pid_file"

# q - suppress debugging info
# B - daemonize
wpa_supplicant \
	- q \
	-B \
	-i "$device" \
	-c "$config" \
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
dhclient_pid_file=$(mktemp /tmp/ias_check_wpa_supplicant-dhclient_pid.XXXXXX)
debug_message "dhclient_pid_file: $dhclient_pid_file"

dhclient -pf "$dhclient_pid_file" "$device" > /dev/null &

found_ip=""

for i in {1..15}
do
	sleep 1
	debug_message "Looping."
	
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

# debug_message "Sleeping while connected."
# sleep 30

nagios_status="CRITICAL"
nagios_exit=2
clean_up_and_exit "TIMEOUT.  IP regex: $wanted_ip_regex . Got IP: $found_ip"
