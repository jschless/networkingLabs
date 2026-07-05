#!/bin/bash
# client — reaches the backend through the firewall pair's OUTSIDE VIP.
ip addr replace 10.10.0.10/24 dev eth1
ip link set eth1 up
# default via the OUTSIDE VIP (10.10.0.1) — whichever firewall holds it.
# replace, not add: containerlab already put a mgmt default on eth0.
ip route replace default via 10.10.0.1
echo "[client] 10.10.0.10/24, default via VIP 10.10.0.1"
