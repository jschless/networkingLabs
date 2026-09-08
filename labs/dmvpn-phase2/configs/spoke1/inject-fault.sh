#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Replace only spoke1's resolved service-host map with an unreachable NBMA.
source /opt/vyatta/etc/functions/script-template

configure
set protocols nhrp tunnel tun0 map tunnel-ip '192.168.2.1' nbma '10.0.0.254'
commit
exit
