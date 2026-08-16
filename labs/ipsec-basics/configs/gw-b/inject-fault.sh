#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Change only the live IKE hash; intentionally do not save the broken state.
source /opt/vyatta/etc/functions/script-template

configure
set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash 'sha512'
commit
exit
