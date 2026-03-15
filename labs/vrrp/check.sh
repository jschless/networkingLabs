#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "vrrp"

check_contains "r1 VRRP Master" "$(eos r1 'show vrrp')" "Master"
check_ping_linux "host→VIP" host 192.168.1.254
check_ping_linux "host→server loopback" host 10.99.0.1

summary
