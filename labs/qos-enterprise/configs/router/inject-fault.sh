#!/bin/vbash
# shellcheck shell=bash

# shellcheck disable=SC1091
source /opt/vyatta/etc/functions/script-template

configure
delete qos policy shaper WAN-QOS class 10 match VOICE
# `set` is provided by the VyOS script template.
# shellcheck disable=SC2121
set qos policy shaper WAN-QOS class 10 match VOICE ip dscp CS6
commit
exit
