#!/bin/sh
# This script creates bonding interfaces on RHEL 5 & 6.
#
# The first and second parameters are used to specify the enslaved interfaces.
# The third parameter is used to describe the name of the bonding interface.
# The network configuration is collected from the first device.
#
# After running the script please verify the following files:
#    /etc/modprobe.conf                on RHEL5
#    /etc/modprobe.d/bonding.conf      on RHEL6
#    /etc/sysconfig/network-scripts/ifcfg*
#
# LICENSE INFORMATION
#
# This software is released under the BSD license:
#
# Copyright 2010 Reiner Rottmann reiner[at]rottmann.it. All Rights Reserved.
#
# Contributions:
# Richard Mansfield: Modifications for RHEL6; adding of MTU
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# 3. The name of the author may not be used to endorse or promote products derived
# from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
# BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Global variables

SCRIPTNAME=$(basename $0 .sh)

EXIT_SUCCESS=0
EXIT_FAILED=1
EXIT_ERROR=2
EXIT_BUG=10

VERSION="1.0.0"

# Base functions

# This function displays the basic usage
function usage {
echo "Usage: $SCRIPTNAME <first slave interface> <second slave interface> <bonding interface>" >&2
echo "This script bonds two network interfaces on RHEL 5 with the static network config from the first slave interface." >&2
echo >&2
echo "e.g. # ./$SCRIPTNAME eth1 eth3 bond1" >&2
echo >&2
[[ $# -eq 1 ]] && exit $1 || exit $EXIT_FAILED
}

# This function checks that the command is run with the right parameters
function preflightcheck {

# This script needs to be run as root.
if [ $(id -u) -ne 0 ]; then
echo "You need to be root to run this script."
exit $EXIT_FAILED
fi

# Check if we have exactly 3 commandline parameters.

if [ $# -ne 3 ]; then
echo "Commandline parameter is missing. (only $# present)."
usage
exit $EXIT_FAILED
fi

# Check if the first input is correct.
if ! echo $1|grep -q "^eth[0-9]$"; then
echo "The first parameter needs to be an ethernet device (e.g. eth1)."
usage
exit $EXIT_FAILED
fi

# Check if the second input is correct.
if ! echo $2|grep -q "^eth[0-9]$"; then
echo "The second parameter needs to be an ethernet device (e.g. eth3)."
usage
exit $EXIT_FAILED
fi

# Check if the third input is correct.
if ! echo $3|grep -q "^bond[0-9]$"; then
echo "The third parameter needs to be a bonding device (e.g. bond3)."
usage
exit $EXIT_FAILED
fi
}

# The main function that creates the bonding devices.
function rhmkbond {

# RHEL6 uses /etc/modprobe.d directory
if [ -d /etc/modprobe.d ]; then
        BONDCONFIG=/etc/modprobe.d/bonding.conf
else # Assume RHEL5
        BONDCONFIG=/etc/modprove.conf
fi

# Load the bonding kernel module with active-backup mode and set mii link monitoring to 100 ms.
cp /etc/modprobe.conf /tmp/modprobe.conf.bonding
test -f "{BONDCONFIG}" && cp "${BONDCONFIG}" /tmp/modprobe.conf.bonding
cat >> /tmp/modprobe.conf.bonding <<EOF
alias $3 bonding
options $3 mode=1 miimon=100
EOF

cat /tmp/modprobe.conf.bonding|uniq > "${BONDCONFIG}"

# Get interface details
IP=$(/sbin/ifconfig $1|egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}"|sed -n "1p")
NETMASK=$(/sbin/ifconfig $1|egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}"|sed -n "3p")
MACIF1=$(/sbin/ifconfig $1|egrep -o "([[:xdigit:]]{2}[:]){5}[[:xdigit:]]{2}")
MACIF2=$(/sbin/ifconfig $2|egrep -o "([[:xdigit:]]{2}[:]){5}[[:xdigit:]]{2}")
MTU=$(/sbin/ifconfig $1 |egrep -o "MTU:([0-9]*)")
MTU=${MTU#*:}

# Create the bond0 device file.
mv /etc/sysconfig/network-scripts/ifcfg-$3 /etc/sysconfig/network-scripts/ifcfg-$3.orig 2>/dev/null
cat >> /etc/sysconfig/network-scripts/ifcfg-$3 <<BOND
DEVICE=$3
BOOTPROTO=none
ONBOOT=yes
$(/bin/ipcalc -n $IP $NETMASK)
NETMASK=$NETMASK
IPADDR=$IP
USERCTL=no
MTU=$MTU
BOND

# Create the slave device files.
for i in $1 $2
do
cp  /etc/sysconfig/network-scripts/ifcfg-$i  /etc/sysconfig/network-scripts/ifcfg-${i}X 2>/dev/null
cat >> /etc/sysconfig/network-scripts/ifcfg-$i <<IFS
DEVICE=$i
BOOTPROTO=none
HWADDR=$(/sbin/ifconfig $i|egrep -o "([[:xdigit:]]{2}[:]){5}[[:xdigit:]]{2}")
ONBOOT=yes
MASTER=$3
SLAVE=yes
USERCTL=no
IFS
done

}

# Call functions
preflightcheck $1 $2 $3
rhmkbond $1 $2 $3

# End script

exit $EXIT_SUCCESS
