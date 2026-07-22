#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "cloud-hybrid-networking"

check_contains "edge1 eBGP established" "$(eos onprem-edge1 'show ip bgp summary')" '169\.254\.60\.2.*Estab'
check_contains "edge2 eBGP established" "$(eos onprem-edge2 'show ip bgp summary')" '169\.254\.60\.6.*Estab'
check_contains "transit has edge1 enterprise attachment" "$(frr cloud-transit 'show bgp summary')" '169\.254\.60\.1'
check_contains "transit has edge2 enterprise attachment" "$(frr cloud-transit 'show bgp summary')" '169\.254\.60\.5'
check_contains "edge1 learns App A route" "$(eos onprem-edge1 'show ip route 10.61.10.10')" '10\.61\.10\.10/32'
check_contains "edge1 has viable high-distance backup" "$(eos onprem-edge1 'show running-config | include ip route 10.61')" '10\.60\.10\.2 250'
check_contains "edge1 has private-DNS backup" "$(eos onprem-edge1 'show running-config | include ip route 10.63')" '10\.60\.10\.2 250'

check_contains "App A reaches private DNS" "$(node app-a-rtr 'dig +short @10.63.10.53 api.prod.corp')" '^10\.61\.10\.10$'
check_contains "App B reaches private DNS" "$(node app-b-rtr 'dig +short @10.63.10.53 api.prod.corp')" '^10\.61\.10\.10$'
check_not_contains "untrusted client has no private DNS answer" "$(node public-client 'dig +short @10.63.10.53 api.prod.corp')" '10\.61\.10\.10'
check_contains "corporate client reaches App A HTTPS by private name" "$(node corp-client 'curl -ks --max-time 5 https://api.prod.corp:8443')" 's_server'
check_not_contains "corporate client cannot reach App B restricted port" "$(node corp-client 'curl -ks --max-time 3 https://10.62.10.10:8443 2>&1 || true')" 's_server'
check_not_contains "App A and App B are isolated" "$(node app-a-rtr 'ip route show table 101')" '10\.62\.10\.10'
check_contains "inspection has stateful reply evidence" "$(node inspection 'nft list chain inet inspection forward')" 'ct state established,related counter packets [1-9]'
check_contains "inspection has HTTPS request evidence" "$(node inspection 'nft list chain inet inspection forward')" 'tcp dport 8443 ct state new counter packets [1-9]'
check_contains "App A uses inspection return association" "$(node app-a-rtr 'ip route get 10.60.10.10 from 10.61.10.10')" 'via 10\.60\.100\.13'
check_not_contains "transit has no data-plane default route" "$(node cloud-transit "ip route show default | grep -v 'dev eth0' || true")" '.'
check_not_contains "App A has no active overlap fixture" "$(node app-a-rtr 'ip route show table 102')" '10\.60\.10\.0/24'

docker exec clab-cloud-hybrid-networking-onprem-edge1 Cli -p 15 -c $'configure\ninterface Ethernet1\n shutdown\nend' >/dev/null
sleep 10
check_contains "fresh HTTPS session survives primary attachment loss" "$(node corp-client 'curl -ks --max-time 5 https://api.prod.corp:8443')" 's_server'
docker exec clab-cloud-hybrid-networking-onprem-edge1 Cli -p 15 -c $'configure\ninterface Ethernet1\n no shutdown\nend' >/dev/null
sleep 12
check_contains "primary attachment re-establishes" "$(eos onprem-edge1 'show ip bgp summary')" '169\.254\.60\.2.*Estab'

summary
