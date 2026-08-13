#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Apply and save Site B's complete healthy learned IPsec state.
source /opt/vyatta/etc/functions/script-template

configure
delete vpn ipsec
set vpn ipsec ike-group SITE-TO-SITE key-exchange 'ikev2'
set vpn ipsec ike-group SITE-TO-SITE proposal 10 encryption 'aes256'
set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash 'sha256'
set vpn ipsec ike-group SITE-TO-SITE proposal 10 dh-group '14'
set vpn ipsec esp-group SITE-TO-SITE mode 'tunnel'
set vpn ipsec esp-group SITE-TO-SITE proposal 10 encryption 'aes256'
set vpn ipsec esp-group SITE-TO-SITE proposal 10 hash 'sha256'
set vpn ipsec authentication psk LAB-PSK id '203.0.113.1'
set vpn ipsec authentication psk LAB-PSK id '203.0.113.6'
set vpn ipsec authentication psk LAB-PSK secret 'LabSecret123'
set vpn ipsec site-to-site peer GW-A remote-address '203.0.113.1'
set vpn ipsec site-to-site peer GW-A authentication mode 'pre-shared-secret'
set vpn ipsec site-to-site peer GW-A authentication local-id '203.0.113.6'
set vpn ipsec site-to-site peer GW-A authentication remote-id '203.0.113.1'
set vpn ipsec site-to-site peer GW-A connection-type 'none'
set vpn ipsec site-to-site peer GW-A local-address '203.0.113.6'
set vpn ipsec site-to-site peer GW-A ike-group 'SITE-TO-SITE'
set vpn ipsec site-to-site peer GW-A default-esp-group 'SITE-TO-SITE'
set vpn ipsec site-to-site peer GW-A tunnel 1 local prefix '192.168.2.0/24'
set vpn ipsec site-to-site peer GW-A tunnel 1 remote prefix '192.168.1.0/24'
commit
save
exit
