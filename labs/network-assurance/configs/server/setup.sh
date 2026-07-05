#!/bin/bash
set -e
ip link set eth1 up
ip addr add 10.3.0.2/30 dev eth1
# "replace": the containerlab mgmt default route already exists; a plain "add"
# fails and leaves the node without a route to the far side.
ip route replace default via 10.3.0.1
echo "[server] Ready: 10.3.0.2/30, gw 10.3.0.1"
