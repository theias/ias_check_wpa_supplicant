# ias_check_wpa_supplicant

A Nagios check using wpa_supplicant and dhclient to connect to a network,
get an IP, and use a regular expression to match the IP.

# License

copyright (C) 2017 Martin VanWinkle, Institute for Advanced Study

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

See 

* http://www.gnu.org/licenses/

## Description

The idea is that you install it on a system that has a network connection, and a wireless card.

The wireless card should be disabled in NetworkManager per the instructions in the script.

You need an appropriate wpa_supplicant configuration for the network you're going to test.

The script needs to run as root.  I suspect you could use sudo to allow the
nagios user to run this script specifically.  The script will attempt to
connect, get an IP, and compare that with a regular expression (which, by
default just looks for a /24 in the output of "ip -br ...").

If it the connection works, it can optionally stay connected for a number of
seconds, then it disconnects, and shuts down the dhclient and wpa_supplicant
processes associated with the test.

I also suspect you could use NRPE on a nagios server to make the call to the
computer to run the check.

In src/bin:

* ias_check_wpa_supplicant.sh - the nagios check
* run_me.sh - an example of how to run the script
* bash_lib.sh - contains functions for this

# Supplemental Documentation

Supplemental documentation for this project can be found here:

* [Supplemental Documentation](./doc/index.md)

# Installation

Ideally stuff should run if you clone the git repo, and install the deps specified
in either "deb_control" or "rpm_specific"

Optionally, you can build a package which will install the binaries in

* /opt/IAS/bin/ias-check-wpa-supplicant/.

# Building a Package

## Requirements

### All Systems

* fakeroot

### Debian

* build-essential

### RHEL based systems

* rpm-build

## Export a specific tag (or the project directory)

## Supported Systems

### Debian packages

```
  fakeroot make package-deb
```

### RHEL Based Systems

```
fakeroot make package-rpm
```

