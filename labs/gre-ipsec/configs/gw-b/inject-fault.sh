#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Change only the live ESP hash; intentionally do not save the broken state.
source /opt/vyatta/etc/functions/script-template

configure
set vpn ipsec esp-group GRE-IPSEC proposal 10 hash 'sha512'
commit
exit
