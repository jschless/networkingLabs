#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Restore only the live spoke1-to-spoke2 IPsec definition.
source /opt/vyatta/etc/functions/script-template
configure
set vpn ipsec site-to-site peer spoke2 remote-address '10.0.0.12'
set vpn ipsec site-to-site peer spoke2 authentication mode 'x509'
set vpn ipsec site-to-site peer spoke2 authentication local-id 'spoke1.dmvpn.lab'
set vpn ipsec site-to-site peer spoke2 authentication remote-id 'spoke2.dmvpn.lab'
set vpn ipsec site-to-site peer spoke2 authentication x509 certificate 'spoke1-cert'
set vpn ipsec site-to-site peer spoke2 authentication x509 ca-certificate 'DMVPN-CA'
set vpn ipsec site-to-site peer spoke2 connection-type 'initiate'
set vpn ipsec site-to-site peer spoke2 local-address '10.0.0.11'
set vpn ipsec site-to-site peer spoke2 ike-group 'DMVPN-IKE'
set vpn ipsec site-to-site peer spoke2 default-esp-group 'DMVPN-ESP'
set vpn ipsec site-to-site peer spoke2 tunnel 1 protocol 'gre'
commit
exit
