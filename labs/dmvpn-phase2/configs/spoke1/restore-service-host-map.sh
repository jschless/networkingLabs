#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Remove the complete live map parent so redirect/shortcut can resolve anew.
source /opt/vyatta/etc/functions/script-template

configure
delete protocols nhrp tunnel tun0 map
commit
exit
