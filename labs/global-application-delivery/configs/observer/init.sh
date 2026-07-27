#!/bin/sh
set -eu
for spec in "eth1 10.115.20.60" "eth2 10.115.10.60" "eth3 10.115.30.60" "eth4 10.115.40.60"; do
    set -- $spec
    ip addr flush dev "$1"
    ip addr add "$2/24" dev "$1"
    ip link set "$1" up
done
ip route replace 192.0.2.0/24 dev eth1
ip route replace 198.51.100.0/24 dev eth1
cp /opt/gad/pki/ca.crt /usr/local/share/ca-certificates/gad-lab-ca.crt
update-ca-certificates >/dev/null 2>&1
