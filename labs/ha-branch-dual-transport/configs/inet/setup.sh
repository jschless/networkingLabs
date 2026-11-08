#!/usr/bin/env bash
# inet — "the Internet": plain IP forwarding between the two public circuits.
# Carries br2<->hub GRE packets; knows nothing about private (10.x) space.
set -euo pipefail
ip link set eth1 up
ip link set eth2 up
ip addr add 198.51.100.2/30 dev eth1
ip addr add 203.0.113.2/30 dev eth2
