#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "urpf-antispoofing"

# Legitimate traffic: attacker's real IP 10.0.0.10 to internet
check_ping_linux "attacker→internet (real IP)" attacker 10.0.0.100
# uRPF is configured on edge — check it's present
check_contains "uRPF configured on edge eth1" "$(frr edge 'show ip interface eth1')" "rpf"

summary
