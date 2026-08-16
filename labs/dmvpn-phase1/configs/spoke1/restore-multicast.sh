#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Restore only the live multicast replication target; saved state stays intact.
source /opt/vyatta/etc/functions/script-template

configure
delete protocols nhrp tunnel tun0 multicast '10.0.0.254'
set protocols nhrp tunnel tun0 multicast '10.0.0.1'
commit
exit
