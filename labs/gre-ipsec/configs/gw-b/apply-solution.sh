#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Replace and save Site B's complete learned GRE-protection definition.
source /opt/vyatta/etc/functions/script-template

configure
delete vpn ipsec
set vpn ipsec ike-group GRE-IPSEC key-exchange 'ikev2'
set vpn ipsec ike-group GRE-IPSEC proposal 10 encryption 'aes256'
set vpn ipsec ike-group GRE-IPSEC proposal 10 hash 'sha256'
set vpn ipsec ike-group GRE-IPSEC proposal 10 dh-group '14'
set vpn ipsec esp-group GRE-IPSEC mode 'transport'
set vpn ipsec esp-group GRE-IPSEC proposal 10 encryption 'aes256'
set vpn ipsec esp-group GRE-IPSEC proposal 10 hash 'sha256'
set vpn ipsec authentication psk LAB-PSK id '203.0.113.1'
set vpn ipsec authentication psk LAB-PSK id '203.0.113.6'
set vpn ipsec authentication psk LAB-PSK secret 'GreIpsecLab123'
set vpn ipsec site-to-site peer GW-A remote-address '203.0.113.1'
set vpn ipsec site-to-site peer GW-A authentication mode 'pre-shared-secret'
set vpn ipsec site-to-site peer GW-A authentication local-id '203.0.113.6'
set vpn ipsec site-to-site peer GW-A authentication remote-id '203.0.113.1'
set vpn ipsec site-to-site peer GW-A connection-type 'none'
set vpn ipsec site-to-site peer GW-A local-address '203.0.113.6'
set vpn ipsec site-to-site peer GW-A ike-group 'GRE-IPSEC'
set vpn ipsec site-to-site peer GW-A default-esp-group 'GRE-IPSEC'
set vpn ipsec site-to-site peer GW-A tunnel 1 protocol 'gre'
commit
save
exit
