#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Restore only spoke1's live ability to consume NHRP redirects.
source /opt/vyatta/etc/functions/script-template

configure
set protocols nhrp tunnel tun0 shortcut
commit
exit
