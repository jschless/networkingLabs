#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Remove only the live spoke2-to-spoke1 IPsec definition.
source /opt/vyatta/etc/functions/script-template
configure
delete vpn ipsec site-to-site peer spoke1
commit
exit
