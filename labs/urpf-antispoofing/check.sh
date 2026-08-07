#!/usr/bin/env bash
# Assert the solved VyOS strict-uRPF target and generate fresh drop evidence.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "urpf-antispoofing"

container_image() {
  docker inspect --format '{{.Config.Image}}' \
    "clab-${TOPO_NAME}-$1" 2>/dev/null
}

urpf_drop_count() {
  local rules="$1" count
  count="$(printf '%s\n' "$rules" | sed -nE \
    's/.*iifname "eth1" fib saddr \. iif oif 0 counter packets ([0-9]+).*/\1/p' | \
    head -n 1)"
  printf '%s\n' "${count:-0}"
}

check_contains "edge uses the validated VyOS image" \
  "$(container_image edge)" '^vyos:local$'
check_contains "attacker is an incidental Linux endpoint" \
  "$(container_image attacker)" '^ops-lab:local$'
check_contains "internet is an incidental Linux endpoint" \
  "$(container_image internet)" '^ops-lab:local$'

attacker_addresses="$(node attacker 'ip -4 -o address show')"
edge_addresses="$(node edge 'ip -4 -o address show')"
internet_addresses="$(node internet 'ip -4 -o address show')"

check_contains "attacker link address is correct" "$attacker_addresses" \
  'eth1[[:space:]]+inet 10\.10\.1\.1/30'
check_contains "attacker has the legitimate alternate source" \
  "$attacker_addresses" 'lo[[:space:]]+inet 10\.0\.0\.10/32'
check_contains "attacker has the known-route spoof source" \
  "$attacker_addresses" 'lo[[:space:]]+inet 10\.99\.99\.1/32'
check_contains "attacker has the unrouted spoof source" \
  "$attacker_addresses" 'lo[[:space:]]+inet 10\.88\.88\.1/32'
check_contains "edge source-facing address is correct" "$edge_addresses" \
  'eth1[[:space:]]+inet 10\.10\.1\.2/30'
check_contains "edge internet-facing address is correct" "$edge_addresses" \
  'eth2[[:space:]]+inet 10\.10\.2\.1/30'
check_contains "internet endpoint address is correct" "$internet_addresses" \
  'eth1[[:space:]]+inet 10\.10\.2\.2/30'

config="$(vyos_op edge 'show configuration commands')"
check_contains "strict source validation is configured exactly on eth1" \
  "$config" "^set interfaces ethernet eth1 ip source-validation 'strict'$"
check_not_contains "eth1 is not left in loose or disabled mode" \
  "$config" "^set interfaces ethernet eth1 ip source-validation '(loose|disable)'$"
check_not_contains "source validation is absent from every other interface" \
  "$config" '^set interfaces ethernet (eth0|eth2).*source-validation'
check_contains "the legitimate source route points toward eth1" \
  "$config" "^set protocols static route '?(10\\.0\\.0\\.10/32)'? next-hop '?(10\\.10\\.1\\.1)'?$"
check_not_contains "the legitimate source route does not point toward eth2" \
  "$config" "^set protocols static route '?(10\\.0\\.0\\.10/32)'? next-hop '?(10\\.10\\.2\\.2)'?$"
check_not_contains "the known spoof experiment route is absent" \
  "$config" "^set protocols static route '?(10\\.99\\.99\\.0/24)'?"
check_not_contains "the main-table default-route experiment is absent" \
  "$config" "^set protocols static route '?(0\\.0\\.0\\.0/0)'?"

check_contains "management eth0 is isolated in MGMT" \
  "$config" "^set interfaces ethernet eth0 vrf 'MGMT'$"
check_contains "MGMT uses routing table 100" \
  "$config" "^set vrf name MGMT table '100'$"
check_contains "MGMT has its own management default" \
  "$config" "^set vrf name MGMT protocols static route '?(0\\.0\\.0\\.0/0)'? next-hop '?(172\\.20\\.20\\.1)'?$"

main_routes="$(node edge 'ip -4 route show table main')"
mgmt_routes="$(node edge 'ip -4 route show table 100')"
check_not_contains "the runtime main table has no known spoof experiment route" \
  "$main_routes" '^10\.99\.99\.0/24([[:space:]]|$)'
check_contains "the installed source route returns through eth1" \
  "$main_routes" '^10\.0\.0\.10 (nhid [0-9]+ )?via 10\.10\.1\.1 dev eth1'
check_not_contains "the data-plane main table has no default" \
  "$main_routes" '^default([[:space:]]|$)'
check_contains "table 100 carries the management default" \
  "$mgmt_routes" '^default .*via 172\.20\.20\.1 dev eth0'

nft_before="$(node edge 'nft list chain ip raw vyos_rpfilter')"
check_contains "VyOS rendered the strict reverse-interface lookup" \
  "$nft_before" 'iifname "eth1" fib saddr \. iif oif 0 counter packets [0-9]+ bytes [0-9]+ drop'
check_contains "VyOS rendered the eth1 uRPF return rule" \
  "$nft_before" 'iifname "eth1" counter packets [0-9]+ bytes [0-9]+ return'

check_ping_linux "legitimate 10.0.0.10 source crosses strict uRPF" \
  attacker 10.10.2.2 10.0.0.10

capture_file="$(mktemp)"
capture_pid=""
cleanup_capture() {
  if [[ -n "$capture_pid" ]]; then
    kill "$capture_pid" 2>/dev/null || true
    wait "$capture_pid" 2>/dev/null || true
  fi
  rm -f "$capture_file"
}
trap cleanup_capture EXIT

docker exec "clab-${TOPO_NAME}-internet" timeout 4 \
  tcpdump -lnni eth1 -c 1 \
  'icmp[icmptype] == icmp-echo and src host 10.99.99.1 and dst host 10.10.2.2' \
  >"$capture_file" 2>&1 &
capture_pid="$!"
sleep 0.4
docker exec "clab-${TOPO_NAME}-attacker" \
  ping -c 2 -W 1 -I 10.99.99.1 10.10.2.2 &>/dev/null || true
wait "$capture_pid" 2>/dev/null || true
capture_pid=""

nft_after="$(node edge 'nft list chain ip raw vyos_rpfilter')"
drop_before="$(urpf_drop_count "$nft_before")"
drop_after="$(urpf_drop_count "$nft_after")"
if [[ "$drop_before" =~ ^[0-9]+$ && "$drop_after" =~ ^[0-9]+$ ]] && \
    (( drop_after > drop_before )); then
  pass "fresh spoof traffic increments the strict uRPF drop counter"
else
  fail "fresh spoof traffic increments the strict uRPF drop counter" \
    "strict drop packets did not increase (${drop_before} -> ${drop_after})"
fi

capture_output="$(<"$capture_file")"
check_contains "bounded internet capture started successfully" \
  "$capture_output" 'listening on eth1'
check_not_contains "internet capture sees no forwarded spoof request" \
  "$capture_output" '10\.99\.99\.1 > 10\.10\.2\.2'

summary
