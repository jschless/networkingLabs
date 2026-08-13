#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Move only the live OSPF multicast replication target; do not save the fault.
source /opt/vyatta/etc/functions/script-template

configure
delete protocols nhrp tunnel tun0 multicast '10.0.0.1'
set protocols nhrp tunnel tun0 multicast '10.0.0.254'
commit
exit
