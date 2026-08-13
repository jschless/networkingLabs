#!/usr/bin/env bash
# Grade the exact healthy GRE/OSPF end state without changing configuration.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "gre-basics"

container() { printf 'clab-%s-%s\n' "$TOPO_NAME" "$1"; }
safe_node() { docker exec "$(container "$1")" bash -c "$2" 2>/dev/null; }
container_image() { docker inspect --format '{{.Config.Image}}' "$(container "$1")" 2>/dev/null; }

assert_match() {
    local label=$1 value=$2 pattern=$3
    if grep -qE "$pattern" <<<"$value"; then
        pass "$label"
    else
        fail "$label" "observed state does not satisfy the lab contract"
    fi
}

assert_not_match() {
    local label=$1 value=$2 pattern=$3
    if ! grep -qE "$pattern" <<<"$value"; then
        pass "$label"
    else
        fail "$label" "unexpected state remains active"
    fi
}

assert_equal() {
    local label=$1 value=$2 expected=$3
    if [[ "$value" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" "observed state differs from the lab contract"
    fi
}

assert_ping_linux() {
    local label=$1 node_name=$2 destination=$3
    if docker exec "$(container "$node_name")" ping -c 2 -W 1 "$destination" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label" "the required path is not forwarding"
    fi
}

assert_ping_eos() {
    local label=$1 node_name=$2 destination=$3 output
    output=$(eos "$node_name" "ping $destination repeat 2 timeout 1")
    if grep -qE '0% packet loss|bytes from' <<<"$output"; then
        pass "$label"
    else
        fail "$label" "the required path is not forwarding"
    fi
}

actual_nodes=$(docker ps --format '{{.Names}}' | sed -n \
    "s/^clab-${TOPO_NAME}-//p" | LC_ALL=C sort)
assert_equal "inventory contains exactly the five intended nodes" "$actual_nodes" \
    $'gw-a\ngw-b\nhost-a\nhost-b\ninternet'

assert_equal "gw-a uses native cEOS" "$(container_image gw-a)" 'ceos:4.35.2F'
assert_equal "gw-b uses native cEOS" "$(container_image gw-b)" 'ceos:4.35.2F'
for incidental in host-a host-b internet; do
    assert_equal "$incidental uses the incidental Linux image" \
        "$(container_image "$incidental")" 'ops-lab:local'
done

assert_match "host-a has its exact LAN address" \
    "$(safe_node host-a 'ip -4 -o address show dev eth1')" \
    'eth1[[:space:]]+inet 192\.168\.1\.10/24'
assert_match "host-b has its exact LAN address" \
    "$(safe_node host-b 'ip -4 -o address show dev eth1')" \
    'eth1[[:space:]]+inet 192\.168\.2\.10/24'
assert_match "host-a has its exact default path" \
    "$(safe_node host-a 'ip -4 route show default')" \
    '^default via 192\.168\.1\.1 dev eth1([[:space:]]|$)'
assert_match "host-b has its exact default path" \
    "$(safe_node host-b 'ip -4 route show default')" \
    '^default via 192\.168\.2\.1 dev eth1([[:space:]]|$)'

internet_addresses=$(safe_node internet 'ip -4 -o address show')
assert_match "transit has the Site A /30 address" "$internet_addresses" \
    'eth1[[:space:]]+inet 203\.0\.113\.2/30'
assert_match "transit has the Site B /30 address" "$internet_addresses" \
    'eth2[[:space:]]+inet 203\.0\.113\.5/30'
assert_equal "transit IPv4 forwarding is enabled" \
    "$(safe_node internet 'sysctl -n net.ipv4.ip_forward')" '1'

assert_equal "gw-a forwarding readiness completed" \
    "$(safe_node gw-a 'cat /tmp/gre-basics-eos-forward.ready')" 'ready:eth1'
assert_equal "gw-b forwarding readiness completed" \
    "$(safe_node gw-b 'cat /tmp/gre-basics-eos-forward.ready')" 'ready:eth2'
if ! safe_node gw-a 'iptables -w 1 -C EOS_FORWARD -i eth1 -j DROP' >/dev/null; then
    pass "gw-a LAN ingress DROP is absent"
else
    fail "gw-a LAN ingress DROP is absent" "forwarding bootstrap is incomplete"
fi
if ! safe_node gw-b 'iptables -w 1 -C EOS_FORWARD -i eth2 -j DROP' >/dev/null; then
    pass "gw-b LAN ingress DROP is absent"
else
    fail "gw-b LAN ingress DROP is absent" "forwarding bootstrap is incomplete"
fi

a_tunnel=$(eos gw-a 'show running-config interfaces Tunnel0')
b_tunnel=$(eos gw-b 'show running-config interfaces Tunnel0')
for item in \
    'gw-a source|tunnel source interface Ethernet2' \
    'gw-a destination|tunnel destination 203\.0\.113\.6' \
    'gw-a address|ip address 172\.16\.0\.1/30' \
    'gw-b source|tunnel source interface Ethernet1' \
    'gw-b destination|tunnel destination 203\.0\.113\.1' \
    'gw-b address|ip address 172\.16\.0\.2/30'; do
    label=${item%%|*}
    pattern=${item#*|}
    if [[ "$label" == gw-a* ]]; then state=$a_tunnel; else state=$b_tunnel; fi
    assert_match "$label is declared natively" "$state" "^[[:space:]]*${pattern}[[:space:]]*$"
done
for item in \
    'gw-a PMTUD|tunnel path-mtu-discovery' \
    'gw-a outer TTL|tunnel ttl 255' \
    'gw-a OSPF area|ip ospf area (0|0\.0\.0\.0)' \
    'gw-a point-to-point network|ip ospf network point-to-point' \
    'gw-b PMTUD|tunnel path-mtu-discovery' \
    'gw-b outer TTL|tunnel ttl 255' \
    'gw-b OSPF area|ip ospf area (0|0\.0\.0\.0)' \
    'gw-b point-to-point network|ip ospf network point-to-point'; do
    label=${item%%|*}
    pattern=${item#*|}
    if [[ "$label" == gw-a* ]]; then state=$a_tunnel; else state=$b_tunnel; fi
    assert_match "$label is exact" "$state" "^[[:space:]]*${pattern}[[:space:]]*$"
done

a_lan=$(eos gw-a 'show running-config interfaces Ethernet1')
b_lan=$(eos gw-b 'show running-config interfaces Ethernet2')
assert_match "gw-a LAN participates in OSPF" "$a_lan" \
    '^[[:space:]]*ip ospf area (0|0\.0\.0\.0)[[:space:]]*$'
assert_match "gw-b LAN participates in OSPF" "$b_lan" \
    '^[[:space:]]*ip ospf area (0|0\.0\.0\.0)[[:space:]]*$'

a_ospf_config=$(eos gw-a 'show running-config section router ospf')
b_ospf_config=$(eos gw-b 'show running-config section router ospf')
assert_match "gw-a OSPF router ID is exact" "$a_ospf_config" \
    '^[[:space:]]*router-id 10\.0\.0\.1[[:space:]]*$'
assert_match "gw-b OSPF router ID is exact" "$b_ospf_config" \
    '^[[:space:]]*router-id 10\.0\.0\.2[[:space:]]*$'
assert_match "gw-a LAN is passive" "$a_ospf_config" \
    '^[[:space:]]*passive-interface Ethernet1[[:space:]]*$'
assert_match "gw-b LAN is passive" "$b_ospf_config" \
    '^[[:space:]]*passive-interface Ethernet2[[:space:]]*$'
assert_match "gw-a permits tunnel-learned routes" "$a_ospf_config" \
    '^[[:space:]]*tunnel routes[[:space:]]*$'
assert_match "gw-b permits tunnel-learned routes" "$b_ospf_config" \
    '^[[:space:]]*tunnel routes[[:space:]]*$'

a_neighbors=$(eos gw-a 'show ip ospf neighbor')
b_neighbors=$(eos gw-b 'show ip ospf neighbor')
assert_match "gw-a has the intended Full neighbor" "$a_neighbors" \
    '10\.0\.0\.2.*[Ff][Uu][Ll][Ll]'
assert_match "gw-b has the intended Full neighbor" "$b_neighbors" \
    '10\.0\.0\.1.*[Ff][Uu][Ll][Ll]'

a_routes=$(eos gw-a 'show ip route ospf')
b_routes=$(eos gw-b 'show ip route ospf')
a_routes_flat=$(tr '\n' ' ' <<<"$a_routes" | sed -E 's/[[:space:]]+/ /g')
b_routes_flat=$(tr '\n' ' ' <<<"$b_routes" | sed -E 's/[[:space:]]+/ /g')
assert_match "gw-a learns the exact remote LAN through OSPF" "$a_routes_flat" \
    '(^| )O 192\.168\.2\.0/24.*via 172\.16\.0\.2, Tunnel0([ ,]|$)'
assert_match "gw-b learns the exact remote LAN through OSPF" "$b_routes_flat" \
    '(^| )O 192\.168\.1\.0/24.*via 172\.16\.0\.1, Tunnel0([ ,]|$)'

a_routes_config=$(eos gw-a 'show running-config section ip route')
assert_not_match "the recursive endpoint route is absent" "$a_routes_config" \
    'ip route 203\.0\.113\.6/32 172\.16\.0\.2'

assert_ping_eos "gw-a retains underlay next-hop reachability" gw-a 203.0.113.2
assert_ping_eos "gw-b retains underlay next-hop reachability" gw-b 203.0.113.5
assert_ping_eos "the tunnel endpoints are mutually reachable" gw-a 172.16.0.2
assert_ping_linux "Site A reaches Site B through the overlay" host-a 192.168.2.10
assert_ping_linux "Site B reaches Site A through the overlay" host-b 192.168.1.10

summary
