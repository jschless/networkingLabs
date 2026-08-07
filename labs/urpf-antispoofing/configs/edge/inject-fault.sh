#!/bin/vbash
# shellcheck shell=bash

# shellcheck disable=SC1091
source /opt/vyatta/etc/functions/script-template

configure
delete protocols static route 10.0.0.10/32
# `set` is a command supplied by the VyOS script template.
# shellcheck disable=SC2121
set protocols static route 10.0.0.10/32 next-hop 10.10.2.2
commit
exit
