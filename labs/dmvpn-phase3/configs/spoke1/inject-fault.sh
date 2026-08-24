#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Remove only spoke1's live ability to consume NHRP redirects.
source /opt/vyatta/etc/functions/script-template

configure
delete protocols nhrp tunnel tun0 shortcut
commit
exit
