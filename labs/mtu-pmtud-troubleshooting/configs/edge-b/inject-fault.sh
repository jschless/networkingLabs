#!/bin/vbash
# shellcheck shell=bash

# shellcheck disable=SC1091
source /opt/vyatta/etc/functions/script-template

configure
# `set` is supplied by the VyOS script template.
# shellcheck disable=SC2121
set interfaces tunnel tun0 mtu 1300
commit
exit
