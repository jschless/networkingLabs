#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 192.168.99.20/24 dev eth1
tac_plus -G -d 16 -l /dev/stdout -C /etc/tacacs+/tac_plus.conf >/tmp/tac_plus.log 2>&1 &
echo "[tacacs1] TACACS ready on 192.168.99.20"
