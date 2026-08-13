#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Restore only the live ESP hash; intentionally leave saved state intact.
source /opt/vyatta/etc/functions/script-template

configure
set vpn ipsec esp-group GRE-IPSEC proposal 10 hash 'sha256'
commit
exit
