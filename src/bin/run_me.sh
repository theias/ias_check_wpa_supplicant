#!/bin/bash

./ias_check_wpa_supplicant.sh \
	-d wlx00936300a6ad \
	-c ~/.config/IAS/ias_check_wpa_supplicant/wpa_supplicant.conf \
	-r '192.168' \
"$@"
