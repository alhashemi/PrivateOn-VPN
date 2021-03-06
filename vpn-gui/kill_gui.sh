#!/bin/bash
#
# PrivateOn-VPN -- Because privacy matters.
#
# Author: Mikko Rautiainen <info@tietosuojakone.fi>
#         Kimmo R. M. Hovi <kimmo@fairwarning.fi>
#
# Copyright (C) 2014-2015  PrivateOn / Tietosuojakone Oy, Helsinki, Finland
# All rights reserved. Use is subject to license terms.
#

#
#  vpn-gui/kill_gui.sh     This script kills any existing instance of the vpn gui
#
#   Note: This script must be run with root credentials, preferably using sudo.
#


DAEMON=/opt/PrivateOn-VPN/vpn-gui/vpn-gui

# Only root should use this script
if test "$(id -u)" -ne 0; then
	echo "${0##*/}: only root can use ${0##*/}" 1>&2
	exit 1
fi

# Run kill on list because "sudo launch-vpn-gui.sh" produces multiple processes
for PID in $(pgrep -f $DAEMON); do
	kill -9 $PID >/dev/null 2>&1
done
