#!/bin/bash
set -e

ip link set eth1 up
ip addr add 192.168.99.20/24 dev eth1
ip route replace default via 192.168.99.1

# Start TACACS+ in the background so containerlab can finish post-deploy execs.
tac_plus -G -d 16 -l /dev/stdout -C /etc/tacacs+/tac_plus.conf >/tmp/tac_plus.log 2>&1 &
