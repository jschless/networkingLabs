#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Replace and save spoke1's complete learned NHRP and overlay-only OSPF state.
source /opt/vyatta/etc/functions/script-template

configure
delete protocols nhrp
delete protocols ospf
set protocols nhrp tunnel tun0 network-id '1'
set protocols nhrp tunnel tun0 holdtime '300'
set protocols nhrp tunnel tun0 nhs tunnel-ip '172.16.0.1' nbma '10.0.0.1'
set protocols nhrp tunnel tun0 map tunnel-ip '172.16.0.1' nbma '10.0.0.1'
set protocols nhrp tunnel tun0 multicast '10.0.0.1'
set protocols nhrp tunnel tun0 registration-no-unique
set protocols nhrp tunnel tun0 shortcut
set protocols ospf parameters router-id '10.0.0.11'
set protocols ospf area 0 network '172.16.0.11/32'
set protocols ospf interface tun0 network 'point-to-multipoint'
commit
save
exit
