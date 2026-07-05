#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "black-core-routing"

check_contains "enc-a black OSPF neighbor" \
  "$(vyos_op enc-a 'show ip ospf neighbor')" \
  "Full"
check_contains "core1 black OSPF neighbors" \
  "$(vyos_op core1 'show ip ospf neighbor')" \
  "Full"
check_contains "red-a overlay OSPF neighbor" \
  "$(vyos_op red-a 'show ip ospf neighbor')" \
  "Full"
check_contains "red-b overlay OSPF route to site A" \
  "$(vyos_op red-b 'show ip route ospf')" \
  "10\\.10\\.10\\.0/24"
check_contains "red-a overlay route to site B" \
  "$(vyos_op red-a 'show ip route ospf')" \
  "10\\.20\\.20\\.0/24"
check_contains "enc-a IKE SA" \
  "$(vyos_op enc-a 'show vpn ike sa')" \
  "ESTABLISHED|up"
check_contains "enc-b IPsec SA" \
  "$(vyos_op enc-b 'show vpn ipsec sa')" \
  "up"
check_not_contains "core1 no red LAN A route" \
  "$(vyos_op core1 'show ip route')" \
  "10\\.10\\.10\\.0/24"
check_not_contains "core1 no red LAN B route" \
  "$(vyos_op core1 'show ip route')" \
  "10\\.20\\.20\\.0/24"
check_ping_linux "client-a→service-b ping" client-a 10.20.20.10
check_contains "client-a HTTP to service-b" \
  "$(node client-a 'curl -s --max-time 5 http://10.20.20.10')" \
  "Hello from the red service"
check_contains "client-a DNS to service-b" \
  "$(node client-a 'dig @10.20.20.10 red-service.lab +short')" \
  "10\\.20\\.20\\.10"

summary
