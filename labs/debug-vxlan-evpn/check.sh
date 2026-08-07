#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "debug-vxlan-evpn"

PREFIX="clab-${TOPO_NAME}"

assert_match() {
  local label="$1" output="$2" pattern="$3"
  if grep -qE "$pattern" <<<"$output"; then
    pass "$label"
  else
    fail "$label" "expected /$pattern/ in output"
  fi
}

assert_count() {
  local label="$1" output="$2" pattern="$3" expected="$4" count
  count=$(grep -cE "$pattern" <<<"$output" || true)
  if [[ "$count" -eq "$expected" ]]; then
    pass "$label"
  else
    fail "$label" "expected $expected matches for /$pattern/, observed $count"
  fi
}

expected_containers=$'clab-debug-vxlan-evpn-host1\nclab-debug-vxlan-evpn-host2\nclab-debug-vxlan-evpn-spine\nclab-debug-vxlan-evpn-vtep1\nclab-debug-vxlan-evpn-vtep2'
running_containers=$(docker ps --format '{{.Names}}' \
  | grep '^clab-debug-vxlan-evpn-' | sort || true)
if [[ "$running_containers" == "$expected_containers" ]]; then
  pass "exact five-node lab inventory is running"
else
  fail "exact five-node lab inventory is running" "running names differ from topology"
fi

for device in spine vtep1 vtep2; do
  image=$(docker inspect --format '{{.Config.Image}}' "$PREFIX-$device" 2>/dev/null || true)
  if [[ "$image" == "ceos:4.35.2F" ]]; then
    pass "$device uses exact cEOS tag"
  else
    fail "$device uses exact cEOS tag" "observed ${image:-unavailable}"
  fi
  assert_match "$device reports EOS 4.35.2F" "$(eos "$device" 'show version')" '4\.35\.2F'
done
for host in host1 host2; do
  image=$(docker inspect --format '{{.Config.Image}}' "$PREFIX-$host" 2>/dev/null || true)
  if [[ "$image" == "ops-lab:local" ]]; then
    pass "$host uses the incidental ops image"
  else
    fail "$host uses the incidental ops image" "observed ${image:-unavailable}"
  fi
done

declare -A HOST_IP=( [host1]='172.16.0.1/24' [host2]='172.16.0.2/24' )
declare -A HOST_MAC=( [host1]='02:00:00:00:01:01' [host2]='02:00:00:00:02:02' )
for host in host1 host2; do
  ip_state=$(docker exec "$PREFIX-$host" ip -4 -o address show dev eth1 2>/dev/null || true)
  mac_state=$(docker exec "$PREFIX-$host" cat /sys/class/net/eth1/address 2>/dev/null || true)
  link_state=$(docker exec "$PREFIX-$host" cat /sys/class/net/eth1/operstate 2>/dev/null || true)
  assert_match "$host has exact application address" "$ip_state" "inet ${HOST_IP[$host]}([[:space:]]|$)"
  if [[ "$mac_state" == "${HOST_MAC[$host]}" ]]; then
    pass "$host has deterministic application MAC"
  else
    fail "$host has deterministic application MAC" "observed ${mac_state:-unavailable}"
  fi
  if [[ "$link_state" == "up" ]]; then
    pass "$host application link is up"
  else
    fail "$host application link is up" "observed ${link_state:-unavailable}"
  fi
done

assert_match "spine first underlay address is exact" \
  "$(eos spine 'show running-config interfaces Ethernet1')" \
  'ip address 10\.1\.1\.2/30'
assert_match "spine second underlay address is exact" \
  "$(eos spine 'show running-config interfaces Ethernet2')" \
  'ip address 10\.1\.2\.2/30'
assert_match "vtep1 underlay address is exact" \
  "$(eos vtep1 'show running-config interfaces Ethernet1')" \
  'ip address 10\.1\.1\.1/30'
assert_match "vtep2 underlay address is exact" \
  "$(eos vtep2 'show running-config interfaces Ethernet1')" \
  'ip address 10\.1\.2\.1/30'
for device in vtep1 vtep2; do
  assert_match "$device host port is access VLAN 100" \
    "$(eos "$device" 'show running-config interfaces Ethernet2')" \
    'switchport access vlan 100'
done

spine_ospf=$(eos spine 'show ip ospf neighbor')
vtep1_ospf=$(eos vtep1 'show ip ospf neighbor')
vtep2_ospf=$(eos vtep2 'show ip ospf neighbor')
assert_count "spine has exactly two Full OSPF neighbors" "$spine_ospf" '[Ff][Uu][Ll][Ll]' 2
assert_count "vtep1 has exactly one Full OSPF neighbor" "$vtep1_ospf" '[Ff][Uu][Ll][Ll]' 1
assert_count "vtep2 has exactly one Full OSPF neighbor" "$vtep2_ospf" '[Ff][Uu][Ll][Ll]' 1
check_ping_eos "vtep1 reaches vtep2 control loopback" vtep1 10.0.0.2 10.0.0.1
check_ping_eos "vtep2 reaches vtep1 control loopback" vtep2 10.0.0.1 10.0.0.2

spine_evpn=$(eos spine 'show bgp evpn summary')
vtep1_evpn=$(eos vtep1 'show bgp evpn summary')
vtep2_evpn=$(eos vtep2 'show bgp evpn summary')
assert_count "spine has exactly two established EVPN peers" "$spine_evpn" '^[[:space:]]*[0-9.]+[[:space:]].*Estab' 2
assert_match "spine EVPN peer vtep1 is established" "$spine_evpn" '^[[:space:]]*10\.0\.0\.1[[:space:]].*Estab'
assert_match "spine EVPN peer vtep2 is established" "$spine_evpn" '^[[:space:]]*10\.0\.0\.2[[:space:]].*Estab'
assert_count "vtep1 has exactly one established EVPN peer" "$vtep1_evpn" '^[[:space:]]*10\.0\.0\.100[[:space:]].*Estab' 1
assert_count "vtep2 has exactly one established EVPN peer" "$vtep2_evpn" '^[[:space:]]*10\.0\.0\.100[[:space:]].*Estab' 1

for device in vtep1 vtep2; do
  vxlan_config=$(eos "$device" 'show running-config interfaces Vxlan1')
  assert_match "$device uses Loopback0 as its VXLAN source" "$vxlan_config" \
    'vxlan source-interface Loopback0'
  assert_match "$device maps VLAN 100 to VNI 100" "$vxlan_config" \
    'vxlan vlan 100 vni 100'
  assert_match "$device reports VNI 100 operational state" \
    "$(eos "$device" 'show vxlan vni')" '(^|[[:space:]])100([[:space:]]|$)'
done

# Seed only bounded application traffic so dynamic MAC/IP evidence is present.
docker exec "$PREFIX-host1" ping -c 3 -W 2 172.16.0.2 >/dev/null 2>&1 || true
docker exec "$PREFIX-host2" ping -c 3 -W 2 172.16.0.1 >/dev/null 2>&1 || true

vtep1_vteps=$(eos vtep1 'show vxlan vtep')
vtep2_vteps=$(eos vtep2 'show vxlan vtep')
assert_match "vtep1 resolves vtep2 as remote VTEP 10.0.0.2" "$vtep1_vteps" '10\.0\.0\.2'
assert_match "vtep2 resolves vtep1 as remote VTEP 10.0.0.1" "$vtep2_vteps" '10\.0\.0\.1'

imet_routes=$(eos vtep1 'show bgp evpn route-type imet')
mac_routes=$(eos vtep1 'show bgp evpn route-type mac-ip')
vxlan_addresses=$(eos vtep1 'show vxlan address-table')
assert_match "vtep1 has remote IMET evidence from 10.0.0.2" "$imet_routes" '10\.0\.0\.2'
assert_match "vtep1 has host2 Type-2 MAC evidence" "$mac_routes" '0200\.0000\.0202'
assert_match "vtep1 binds host2 MAC to remote VTEP 10.0.0.2" "$vxlan_addresses" \
  '0200\.0000\.0202.*10\.0\.0\.2|10\.0\.0\.2.*0200\.0000\.0202'

check_ping_linux "host1 reaches host2 across VNI 100" host1 172.16.0.2
check_ping_linux "host2 reaches host1 across VNI 100" host2 172.16.0.1

summary
