#!/bin/sh
# c2 — site-2 client (behind r2)
ip addr replace 172.16.2.10/24 dev eth1
# replace, not add: containerlab already installed a default route via
# the management network, and `ip route add default` would silently fail
ip route replace default via 172.16.2.1
