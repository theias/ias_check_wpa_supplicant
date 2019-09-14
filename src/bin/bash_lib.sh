#!/bin/bash

function debug_message
{
	if [[ "$DEBUG_MESSAGES" == 1 ]]
	then
		>&2 echo "DEBUG: $@"
	fi
}

function kill_pid_from_file
{
	# Reads a pid from a file.
	# If it finds the pid in the file, it runs kill $pid
	# If it doesn't find the pid in the file, it searches
	#	ps wwaux for the file, and kills the pid associated
	# with that process.
	
	local file_name="$1"
	
	if [[ -f "$file_name" ]]
	then
		local pid=$( cat "$file_name" )
		
		if [[ ! -z "$pid" ]]
		then
		
			debug_message "Killing $pid from $file_name"
			kill $pid
			rm -f "$file_name"
		else
			debug_message "Didn't get pid from $file_name .  Going for dirty kill..."
			
			pid=$( \
				ps wwaux \
				| grep "$file_name" \
				| grep -v grep \
				| awk '{print $2}' \
			)

			debug_message "Killing $pid from $file_name"
			kill $pid
			
		fi
	fi
}

function clean_up_and_exit
{
	local msg="$1"; shift

	local end_time=$( date +%s )
	
	local duration="$(($end_time-$start_time))"

	kill_pid_from_file "$dhclient_pid_file"
	kill_pid_from_file "$wpa_pid_file"	

	# Flush current IP address(s) from device:
	ip addr flush dev "$device"

	echo "$nagios_status: $nagios_service_name | ${duration}seconds"

	if [[ ! -z "$msg" ]]
	then
		echo $msg
	fi
	
	exit $nagios_exit
}

function ip_br_device_exists
{
	# This relies on ip returning non-zero
	# when querying an interface
	
	local device="$1"

	ip -br addr show "$device" > /dev/null
	local result=$?
	# debug_message "Result of ip exists: $result"
	echo "$result"
}

function ip_br_device_status
{
	local device="$1"

	local ip_br_text=$( ip -br addr show "$device" )
	local device_status=$(echo "$ip_br_text" | awk '{print $2}')

	echo "$device_status"
}

function check_for_ip_br_ipv4
{
	local device="$1"; shift
	local wanted_ip_regex="$1"
	
	local ip_br_text=$( ip -br addr show "$device" )
	debug_message "ip_br_text: ${ip_br_text}"
	
	local ip_from_ip=$(echo "$ip_br_text" | awk '{print $3}')
	
	if [[ "$ip_from_ip" =~  "$wanted_ip_regex" ]]
	then
		debug_message "Wanted IP regex $wanted_ip_regex matched $ip_from_ip."
		echo "$ip_from_ip"
		return 0
	else
		debug_message "IP not found."
		echo "$ip_from_ip"
		return 1
	fi

}

