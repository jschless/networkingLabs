#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Restore only the live IKE hash; intentionally leave the saved state intact.
source /opt/vyatta/etc/functions/script-template

configure
set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash 'sha256'
commit
exit
