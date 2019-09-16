#!/bin/bash

./ias_check_wpa_supplicant.sh \
	-d wlx00936300a6ad \
	-c ~/.config/IAS/ias-check-wpa-supplicant/wpa_supplicant.conf \
	-r '192.168' \
"$@"
