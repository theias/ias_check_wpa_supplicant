#!/bin/bash

device="$1"; shift
config="$1"; shift;
wanted_ip="$1"

. bash_lib.sh

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

if [[ -z "$wanted_ip" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "Error: you must specify what IP you will be given."
fi


# Main section
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
	-P "$wpa_pid_file"

result=$?

if [[ "$result" != "0" ]]
then
	nagios_status="UNKNOWN"
	nagios_exit=3
	clean_up_and_exit "wpa_supplicant exited with $result"
	exit 3
fi

debug_message "Running dhclient."
dhclient_pid_file=$(mktemp /tmp/ias_check_wpa_supplicant-dhclient_pid.XXXXXX)
debug_message "dhclient_pid_file: $dhclient_pid_file"

dhclient -pf "$dhclient_pid_file" "$device" &

found_ip=""

for i in {1..30}
do
	sleep 1
	debug_message "Looping."
	
	device_status=$( ip_br_device_status "$device")
	
	if [[ "$device_status" != "UP" ]]
	then
		debug_message "Device $device status: $device_status"
		continue
	fi
	
	found_ip=$( check_for_ip_br_ipv4 "$device" "$wanted_ip")
	result=$?
	debug_message "Found IP: $found_ip"
	debug_message "Result from check_for_ip_br : $result"
	if [[ "$result" == "0" ]]
	then
		break
	fi
	
done

clean_up_and_exit "Got ip: $found_ip"


