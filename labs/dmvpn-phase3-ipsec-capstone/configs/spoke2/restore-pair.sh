#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Restore only the live spoke2-to-spoke1 IPsec definition.
source /opt/vyatta/etc/functions/script-template
configure
set vpn ipsec site-to-site peer spoke1 remote-address '10.0.0.11'
set vpn ipsec site-to-site peer spoke1 authentication mode 'x509'
set vpn ipsec site-to-site peer spoke1 authentication local-id 'spoke2.dmvpn.lab'
set vpn ipsec site-to-site peer spoke1 authentication remote-id 'spoke1.dmvpn.lab'
set vpn ipsec site-to-site peer spoke1 authentication x509 certificate 'spoke2-cert'
set vpn ipsec site-to-site peer spoke1 authentication x509 ca-certificate 'DMVPN-CA'
set vpn ipsec site-to-site peer spoke1 connection-type 'none'
set vpn ipsec site-to-site peer spoke1 local-address '10.0.0.12'
set vpn ipsec site-to-site peer spoke1 ike-group 'DMVPN-IKE'
set vpn ipsec site-to-site peer spoke1 default-esp-group 'DMVPN-ESP'
set vpn ipsec site-to-site peer spoke1 tunnel 1 protocol 'gre'
commit
exit
