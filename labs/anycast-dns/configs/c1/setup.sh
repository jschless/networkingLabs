#!/bin/sh
# c1 — site-1 client (behind r1)
ip addr replace 172.16.1.10/24 dev eth1
# replace, not add: containerlab already installed a default route via
# the management network, and `ip route add default` would silently fail
ip route replace default via 172.16.1.1
