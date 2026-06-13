#!/bin/bash
# guest-pc — unmanaged guest device on access-sw2 eth2 (open access VLAN 30).
# Gets a lease from Kea via DHCP relay, but the core's GUEST-IN ACL denies it the
# internal services (10.100.0.0/16) — it is Internet-only. See README.
set -e
ip link set eth1 up
# Drop the ContainerLab mgmt default so DHCP installs the campus default route.
ip route del default via 172.20.20.1 dev eth0 2>/dev/null || true
echo "[guest-pc] link up on VLAN 30 (guest). Next: dhclient eth1"
