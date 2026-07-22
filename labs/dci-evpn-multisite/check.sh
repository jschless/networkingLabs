#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dci-evpn-multisite"

check_contains "Site A local EVPN established" "$(eos a-leaf 'show bgp summary')" 'Established.*L2VPN EVPN'
check_contains "Site B local EVPN established" "$(eos b-leaf 'show bgp summary')" 'Established.*L2VPN EVPN'
check_contains "Site A border established" "$(eos a-bgw 'show bgp summary')" '10\.11\.0\.6.*Established'
check_contains "Site B border established" "$(eos b-bgw 'show bgp summary')" '10\.21\.0\.6.*Established'
check_contains "Inter-site EVPN established" "$(eos a-bgw 'show bgp summary')" '10\.255\.10\.2.*Established'

check_contains "Site A installs Site B PROD type-5" "$(eos a-leaf 'show ip route vrf PROD 172.17.10.0/24')" 'via VTEP 10\.20\.0\.1 VNI 50010'
check_contains "Site B installs Site A PROD type-5" "$(eos b-leaf 'show ip route vrf PROD 172.16.10.0/24')" 'via VTEP 10\.10\.0\.3 VNI 50010'
check_contains "Site B installs shared service type-5" "$(eos b-leaf 'show ip route vrf PROD 172.31.10.0/24')" 'VNI 50010'
check_not_contains "Site A DEV has no remote DEV route" "$(eos a-leaf 'show ip route vrf DEV')" '172\.17\.20\.0/24'
check_not_contains "Site B DEV has no remote DEV route" "$(eos b-leaf 'show ip route vrf DEV')" '172\.16\.20\.0/24'

check_ping_linux "Site A PROD client reaches Site B PROD app" a-client 172.17.10.10
check_ping_linux "Site B PROD client reaches Site A shared service" b-client 172.31.10.10
check_ping_linux "Site A PROD client reaches its shared service" a-client 172.31.10.10
check_contains "Site A DEV cannot reach Site B DEV" "$(node a-client 'ping -I 172.16.20.10 -c2 -W2 172.17.20.10 2>&1 || true')" '100% packet loss|Network is unreachable'
check_contains "Site B DEV cannot reach shared service" "$(node b-client 'ping -I 172.17.20.10 -c2 -W2 172.31.10.10 2>&1 || true')" '100% packet loss|Network is unreachable'
check_not_contains "No PROD default-route leak" "$(eos a-leaf 'show ip route vrf PROD')" '0\.0\.0\.0/0'
check_not_contains "No management prefix leak" "$(eos b-leaf 'show ip route vrf PROD')" '172\.20\.20\.'
check_contains "DCI PROD export policy is present" "$(eos a-bgw 'show running-config section route-map')" 'match extcommunity DCI-PROD'

summary
