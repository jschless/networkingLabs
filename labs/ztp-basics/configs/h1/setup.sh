#!/usr/bin/env bash
# h1 — user-segment host behind the switch ZTP will provision.
# Idempotent: reset-sw1.sh re-runs this after re-plumbing the data links.
set -e
ip addr replace 10.0.2.100/24 dev eth1
ip link set eth1 up
# Default via the gateway-to-be; 'replace' because containerlab already
# installed a mgmt default route
ip route replace default via 10.0.2.1
