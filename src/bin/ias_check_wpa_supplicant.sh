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
echo "HERE"
exit

# Main section
wpa_pid_file=$(mktemp /tmp/ias_check_wpa_supplicant-wpa_supplicant_pid.XXXXXX)

debug_message "Running wpa_supplicant."
debug_message "wpa_pid_file: $wpa_pid_file"

wpa_supplicant \
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

wpa_pid=$( cat "$wpa_pid_file"  )

debug_message "Running dhclient."
dhclient_pid_file=$(mktemp /tmp/ias_check_wpa_supplicant-dhclient_pid.XXXXXX)
debug_message "dhclient_pid_file: $dhclient_pid_file"

dhclient -pf "$dhclient_pid_file" "$device" &

for i in {1..30}
do
	sleep 1
	debug_message "Looping."

	if [[ check_for_ip_br ]]
	then
		break
	fi
	
done

clean_up_and_exit


