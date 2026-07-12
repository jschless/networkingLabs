#!/usr/bin/env sh
set -eu

# This is the Linux-node golden reset contract. It is safe to rerun and resets
# mutable networking state without restarting the container.
ip link set eth1 up
ip addr flush dev eth1 scope global || true
ip addr add 192.0.2.10/24 dev eth1
ip route replace default via 192.0.2.1 dev eth1
ip neigh flush dev eth1 || true

# A production endpoint/service reset also restores its local nftables policy
# and process state. This minimal endpoint has neither. Flush conntrack when
# the image provides the command; frr-lab intentionally does not require it.
if command -v conntrack >/dev/null 2>&1; then
    conntrack -F || true
fi
