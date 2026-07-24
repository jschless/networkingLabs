#!/usr/bin/env bash
set -euo pipefail
ip link set lo up
case "$NODE" in
  hub)
    ip addr add 10.113.40.11/24 dev eth1; ip addr add 172.20.113.5/30 dev eth2; ip addr add 192.0.2.116/30 dev eth3; ip addr add 10.113.30.1/24 dev eth4
    ip route replace 172.20.113.0/30 via 172.20.113.6 dev eth2; ip route replace 172.20.113.8/30 via 172.20.113.6 dev eth2
    ip route replace 192.0.2.112/30 via 192.0.2.117 dev eth3; ip route replace 192.0.2.120/30 via 192.0.2.117 dev eth3 ;;
  branch1)
    ip addr add 10.113.40.21/24 dev eth1; ip addr add 172.20.113.1/30 dev eth2; ip addr add 192.0.2.112/30 dev eth3; ip addr add 10.113.10.1/24 dev eth4; ip addr add 10.113.110.1/24 dev eth5
    ip route replace 172.20.113.4/30 via 172.20.113.2 dev eth2; ip route replace 192.0.2.116/30 via 192.0.2.113 dev eth3; ip route replace 10.113.50.0/24 via 192.0.2.113 dev eth3 ;;
  branch2)
    ip addr add 10.113.40.22/24 dev eth1; ip addr add 172.20.113.9/30 dev eth2; ip addr add 192.0.2.120/30 dev eth3; ip addr add 10.113.20.1/24 dev eth4; ip addr add 10.113.120.1/24 dev eth5
    ip route replace 172.20.113.4/30 via 172.20.113.10 dev eth2; ip route replace 192.0.2.116/30 via 192.0.2.121 dev eth3; ip route replace 10.113.50.0/24 via 192.0.2.121 dev eth3 ;;
esac
for i in eth1 eth2 eth3 eth4 eth5; do ip link set "$i" up 2>/dev/null || true; done
mkdir -p "/runtime/edges/$NODE"
chmod -R a+rwx /runtime
echo '{"enrolled":false,"control":"absent","applied_version":null}' > "/runtime/edges/$NODE/status.json"
