#!/bin/sh
set -eu
ip addr flush dev eth1
ip addr add "$1/24" dev eth1
ip link set eth1 up
ip route replace 192.0.2.0/24 dev eth1
ip route replace 198.51.100.0/24 dev eth1
cp /opt/gad/pki/ca.crt /usr/local/share/ca-certificates/gad-lab-ca.crt
update-ca-certificates >/dev/null 2>&1
