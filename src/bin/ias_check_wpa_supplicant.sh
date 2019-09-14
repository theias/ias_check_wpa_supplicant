#!/bin/bash

device="$1"; shift
config="$1"

function debug_message
{
	>&2 echo "$@"
}

function kill_pid_from_file
{
	local file_name="$1"
	
	if [[ -e "$file_name" ]]
	then
	
		kill $( cat "$file_name" )
		rm -f "$file_name"
	fi
}

function clean_up_and_exit
{
	msg="$1"; shift

	end_time=$( date +%s )
	
	duration="$(($end_time-$start_time))"

	kill_pid_from_file "$dhclient_pid_file"
	kill_pid_from_file "$wpa_pid_file"	

	echo "$nagios_status: $nagios_service_name | ${duration}seconds"

	if [[ ! -z "$msg" ]]
	then
		echo $msg
	fi
	
	exit $nagios_exit
}

start_time=$( date +%s )

nagios_service_name="ias_check_wpa_supplicant $device $config"

nagios_status="OK"
nagios_exit="0"


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
	ip_br_text=$( ip -br addr show "$device" )
	debug_message "ip_br_text: ${ip_br_text}"
	
	echo "$ip_br_text" | grep '192\.168'
	result=$?
	
	if [[ "$result" == 0 ]]
	then
		debug_message "IP found."
		break
	else
		debug_message "IP not found."
	fi
done

clean_up_and_exit


