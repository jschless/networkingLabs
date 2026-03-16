#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "gre-ipsec"

check_contains "gw-a IKE SA" "$(vyos_op gw-a 'show vpn ike sa')" "ESTABLISHED|up"
check_contains "gw-b IKE SA" "$(vyos_op gw-b 'show vpn ike sa')" "ESTABLISHED|up"
check_contains "gw-a GRE child SA" "$(vyos_op gw-a 'show vpn ipsec sa')" "GW-B-tunnel-1[[:space:]]+up"
check_contains "gw-b GRE child SA" "$(vyos_op gw-b 'show vpn ipsec sa')" "GW-A-tunnel-1[[:space:]]+up"
check_ping_linux "host-a→host-b" host-a 192.168.2.10
check_ping_linux "host-b→host-a" host-b 192.168.1.10

summary
