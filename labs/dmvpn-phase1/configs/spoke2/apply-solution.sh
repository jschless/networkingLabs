#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Replace and save spoke2's complete learned NHRP and OSPF definition.
source /opt/vyatta/etc/functions/script-template

configure
delete protocols nhrp
delete protocols ospf
set protocols nhrp tunnel tun0 network-id '1'
set protocols nhrp tunnel tun0 holdtime '300'
set protocols nhrp tunnel tun0 nhs tunnel-ip '172.16.0.1' nbma '10.0.0.1'
set protocols nhrp tunnel tun0 map tunnel-ip '172.16.0.1' nbma '10.0.0.1'
set protocols nhrp tunnel tun0 multicast '10.0.0.1'
set protocols ospf parameters router-id '10.0.0.12'
set protocols ospf area 0 network '172.16.0.12/32'
set protocols ospf area 0 network '192.168.2.0/24'
set protocols ospf interface dum0 passive
set protocols ospf interface tun0 network 'point-to-multipoint'
commit
save
exit
