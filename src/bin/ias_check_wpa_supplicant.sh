#!/bin/bash


device="$1"; shift
config="$1"

start_time=$( time )

nagios_service_name="ias_check_wpa_supplicant $device $config"

nagios_status="OK"
nagios_exit="0"

tmpfile=$(mktemp /tmp/ias_check_wpa_supplicant-wpa_supplicant_pid.XXXXXX)

wpa_supplicant \
	-B \
	-i "$device" \
	-c "$config" \
       	-P "$tmpfile"

result=$?

if [[ "$result" != "0" ]]
then
	echo "UNKNOWN: $nagios_service_name"
	echo "wpa_supplicant exited with $result"
	exit 3
fi

pid=$( cat "$tmpfile"  )

function clean_up_and_exit
{
	msg="$1"; shift

	end_time=$( time )
	
	duration="$(($end_time-$start_time))"
	kill $pid
	rm "$tmpfile"

	echo "$nagios_status: $nagios_service_name | ${duration}seconds"

	if [[ ! -z "$msg" ]]
	then
		echo $msg
	fi
	
	exit $nagios_exit
}
