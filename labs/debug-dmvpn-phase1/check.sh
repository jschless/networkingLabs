#!/usr/bin/env bash
# Grade the exact healthy debug-dmvpn-phase1 state without changing config.
set -u

usage() {
    cat <<'EOF'
Usage: labs/debug-dmvpn-phase1/check.sh

Grade exact healthy live state while requiring every saved startup file to
remain the intentional one-leaf incident. Sends only bounded test traffic.
EOF
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
# shellcheck source=state-lib.sh
source "$REPO_ROOT/labs/debug-dmvpn-phase1/state-lib.sh"
lab_init debug-dmvpn-phase1

assert_equal() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" 'observed state differs from the exact lab contract'
    fi
}

assert_match() {
    local label=$1 actual=$2 pattern=$3
    if grep -qE "$pattern" <<<"$actual"; then
        pass "$label"
    else
        fail "$label" 'required correlated state is absent'
    fi
}

assert_absent() {
    local label=$1 actual=$2 pattern=$3
    if ! grep -qE "$pattern" <<<"$actual"; then
        pass "$label"
    else
        fail "$label" 'unexpected bypass or pollution remains'
    fi
}

assert_count() {
    local label=$1 actual=$2 pattern=$3 expected=$4 count
    count=$(grep -Ec "$pattern" <<<"$actual" || true)
    assert_equal "$label" "$count" "$expected"
}

assert_ping() {
    local label=$1 node=$2 source=$3 destination=$4
    if debug_dmvpn_ping "$node" "$source" "$destination"; then
        pass "$label"
    else
        fail "$label" 'bounded source-specific traffic did not arrive'
    fi
}

actual_nodes=$(docker ps --format '{{.Names}}' | sed -n \
    's/^clab-debug-dmvpn-phase1-//p' | LC_ALL=C sort)
assert_equal 'inventory contains exactly the five intended nodes' "$actual_nodes" \
    $'br-wan\nhub\nspoke1\nspoke2\nspoke3'

for node in hub spoke1 spoke2 spoke3; do
    assert_equal "$node uses native VyOS" \
        "$(docker inspect --format '{{.Config.Image}}' \
            "$(debug_dmvpn_container "$node")" 2>/dev/null)" vyos:local
    assert_match "$node reports a live VyOS platform" \
        "$(debug_dmvpn_vyos "$node" 'show version')" 'VyOS'
done
assert_equal 'incidental bridge uses ops-lab:local' \
    "$(docker inspect --format '{{.Config.Image}}' \
        "$(debug_dmvpn_container br-wan)" 2>/dev/null)" ops-lab:local

for node in br-wan hub spoke1 spoke2 spoke3; do
    assert_equal "$node management address inventory is exact" \
        "$(debug_dmvpn_actual_mgmt_addresses "$node")" \
        "$(debug_dmvpn_expected_mgmt_addresses "$node")"
    assert_equal "$node management route inventory is exact" \
        "$(debug_dmvpn_actual_mgmt_routes "$node")" \
        "$(debug_dmvpn_expected_mgmt_routes "$node")"
done

bridge_links=$(debug_dmvpn_node br-wan 'bridge link show master br0')
bridge_ports=$(awk '{ port=$2; sub(/:.*/, "", port); sub(/@.*/, "", port); print port }' \
    <<<"$bridge_links" | LC_ALL=C sort)
assert_equal 'WAN bridge has exactly four intended ports' "$bridge_ports" \
    $'eth1\neth2\neth3\neth4'
assert_count 'all four WAN bridge ports are forwarding' "$bridge_links" \
    'master br0 state forwarding' 4
assert_match 'WAN bridge is operationally up' \
    "$(debug_dmvpn_node br-wan 'ip -o link show dev br0')" 'UP'
assert_equal 'WAN bridge owns no data-plane IPv4 address' \
    "$(debug_dmvpn_node br-wan \
        "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print}'")" ''
assert_equal 'WAN bridge owns no data-plane route' \
    "$(debug_dmvpn_node br-wan \
        "ip -4 route show table main | grep -v ' dev eth0'")" ''

declare -A wan=( [hub]=10.0.0.1 [spoke1]=10.0.0.11 [spoke2]=10.0.0.12 [spoke3]=10.0.0.13 )
declare -A overlay=( [hub]=172.16.0.1 [spoke1]=172.16.0.11 [spoke2]=172.16.0.12 [spoke3]=172.16.0.13 )
all_config=
for node in hub spoke1 spoke2 spoke3; do
    assert_equal "$node WAN address set is exact" \
        "$(debug_dmvpn_interface_v4 "$node" eth1)" "${wan[$node]}/24"
    assert_equal "$node overlay address set is exact" \
        "$(debug_dmvpn_interface_v4 "$node" tun0)" "${overlay[$node]}/32"
    assert_match "$node tun0 is mGRE without a fixed remote" \
        "$(debug_dmvpn_node "$node" 'ip -d link show dev tun0')" \
        'gre remote any local any dev eth1'

    live=$(debug_dmvpn_live_config "$node")
    saved=$(debug_dmvpn_saved_config "$node")
    all_config+=$'\n'"$live"
    assert_equal "$node complete live interface inventory is exact" \
        "$(debug_dmvpn_select '^set interfaces ' <<<"$live")" \
        "$(debug_dmvpn_expected_interfaces "$node")"
    assert_equal "$node complete saved interface inventory is exact" \
        "$(debug_dmvpn_select '^set interfaces ' <<<"$saved")" \
        "$(debug_dmvpn_expected_interfaces "$node")"
    assert_equal "$node live learned protocol inventory is exact and healthy" \
        "$(debug_dmvpn_select '^set protocols ' <<<"$live")" \
        "$(debug_dmvpn_expected_protocols "$node" healthy)"
    assert_equal "$node saved learned protocol inventory is the exact incident" \
        "$(debug_dmvpn_select '^set protocols ' <<<"$saved")" \
        "$(debug_dmvpn_expected_protocols "$node" incident)"
    assert_equal "$node kernel route inventory has no pollution" \
        "$(debug_dmvpn_route_pollution "$node")" ''
done
for number in 1 2 3; do
    assert_equal "spoke$number service address set is exact" \
        "$(debug_dmvpn_interface_v4 "spoke$number" dum0)" \
        "192.168.${number}.1/24"
    assert_equal "spoke$number completed exact startup NHRP normalization" \
        "$(debug_dmvpn_node "spoke$number" \
            'cat /tmp/debug-dmvpn-phase1-map.ready')" \
        "$(debug_dmvpn_startup_marker_expected "spoke$number")"
done

assert_absent 'no redirect, shortcut, or fixed-remote bypass exists' \
    "$all_config" \
    '^set protocols nhrp .*\b(redirect|shortcut)\b|^set interfaces tunnel tun0 remote '
assert_absent 'no static, BGP, IS-IS, or RIP route bypass exists' "$all_config" \
    '^set protocols (static|bgp|isis|rip)([[:space:]]|$)'
assert_absent 'no stale eth1 passive declaration exists' "$all_config" \
    '^set protocols ospf interface eth1 passive$'
assert_absent 'hub does not advertise spoke-owned service LANs' \
    "$(debug_dmvpn_live_config hub)" \
    '^set protocols ospf area .* network 192\.168\.'

hub_nhrp=$(debug_dmvpn_frr hub 'show ip nhrp')
assert_count 'hub NHRP table has exactly four rows' "$hub_nhrp" \
    '^tun0[[:space:]]' 4
assert_match 'hub has one exact local NHRP row' "$hub_nhrp" \
    '^tun0[[:space:]]+local[[:space:]]+172\.16\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+-([[:space:]]|$)'
for number in 1 2 3; do
    last=$((10 + number))
    assert_match "hub correlates spoke$number tunnel and NBMA dynamically" \
        "$hub_nhrp" \
        "^tun0[[:space:]]+dynamic[[:space:]]+172\\.16\\.0\\.${last}[[:space:]]+10\\.0\\.0\\.${last}[[:space:]]+10\\.0\\.0\\.${last}[[:space:]]+T([[:space:]]|$)"
done

for number in 1 2 3; do
    spoke=spoke$number
    last=$((10 + number))
    nhrp=$(debug_dmvpn_frr "$spoke" 'show ip nhrp')
    assert_count "$spoke NHRP table has exactly two rows" "$nhrp" \
        '^tun0[[:space:]]' 2
    assert_match "$spoke has one exact local NHRP row" "$nhrp" \
        "^tun0[[:space:]]+local[[:space:]]+172\\.16\\.0\\.${last}[[:space:]]+10\\.0\\.0\\.${last}[[:space:]]+10\\.0\\.0\\.${last}[[:space:]]+-([[:space:]]|$)"
    assert_match "$spoke has the correct exact static hub mapping" "$nhrp" \
        '^tun0[[:space:]]+static[[:space:]]+172\.16\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+-([[:space:]]|$)'
    for other in 1 2 3; do
        [[ "$other" == "$number" ]] && continue
        assert_absent "$spoke has no direct spoke$other NHRP shortcut" "$nhrp" \
            "172\\.16\\.0\\.$((10 + other))"
    done
done

hub_neighbors=$(debug_dmvpn_frr hub 'show ip ospf neighbor')
assert_count 'hub has exactly three OSPF neighbors' "$hub_neighbors" \
    '^[0-9]+\.' 3
for number in 1 2 3; do
    last=$((10 + number))
    assert_match "hub has spoke$number Full at its exact overlay" \
        "$hub_neighbors" \
        "^10\\.0\\.0\\.${last}[[:space:]].*Full/DROther[[:space:]].*172\\.16\\.0\\.${last}([[:space:]]|$)"
done
for number in 1 2 3; do
    neighbors=$(debug_dmvpn_frr "spoke$number" 'show ip ospf neighbor')
    assert_count "spoke$number has exactly one OSPF neighbor" "$neighbors" \
        '^[0-9]+\.' 1
    assert_match "spoke$number has only the hub Full" "$neighbors" \
        '^10\.0\.0\.1[[:space:]].*Full/DROther[[:space:]].*172\.16\.0\.1([[:space:]]|$)'
done

hub_routes=$(debug_dmvpn_frr hub 'show ip route ospf')
assert_count 'hub learns exactly three service prefixes' "$hub_routes" \
    '^O[^[:space:]]*[[:space:]]+192\.168\.[123]\.0/24' 3
assert_count 'hub learns exactly three spoke overlay prefixes' "$hub_routes" \
    '^O[^[:space:]]*[[:space:]]+172\.16\.0\.(11|12|13)/32' 3
for number in 1 2 3; do
    last=$((10 + number))
    assert_match "hub routes service LAN $number through its owner" "$hub_routes" \
        "^O[^[:space:]]*[[:space:]]+192\\.168\\.${number}\\.0/24.*via 172\\.16\\.0\\.${last}, tun0"
    assert_match "hub routes spoke$number overlay through its owner" "$hub_routes" \
        "^O[^[:space:]]*[[:space:]]+172\\.16\\.0\\.${last}/32.*via 172\\.16\\.0\\.${last}, tun0"
done
for number in 1 2 3; do
    spoke=spoke$number
    routes=$(debug_dmvpn_frr "$spoke" 'show ip route ospf')
    assert_count "$spoke learns exactly two selected remote service routes" \
        "$routes" '^O>\*[[:space:]]+192\.168\.[123]\.0/24' 2
    assert_count "$spoke learns exactly two selected remote overlay routes" \
        "$routes" '^O>\*[[:space:]]+172\.16\.0\.(11|12|13)/32' 2
    for other in 1 2 3; do
        [[ "$other" == "$number" ]] && continue
        last=$((10 + other))
        assert_match "$spoke routes spoke$other service through the hub" \
            "$routes" \
            "^O[^[:space:]]*[[:space:]]+192\\.168\\.${other}\\.0/24.*via 172\\.16\\.0\\.1, tun0"
        assert_match "$spoke routes spoke$other overlay through the hub" \
            "$routes" \
            "^O[^[:space:]]*[[:space:]]+172\\.16\\.0\\.${last}/32.*via 172\\.16\\.0\\.1, tun0"
    done
done

for number in 1 2 3; do
    last=$((10 + number))
    assert_ping "spoke$number underlay reaches the hub" "spoke$number" \
        "10.0.0.$last" 10.0.0.1
    assert_ping "spoke$number overlay reaches the hub" "spoke$number" \
        "172.16.0.$last" 172.16.0.1
done
for source in 1 2 3; do
    for destination in 1 2 3; do
        [[ "$source" == "$destination" ]] && continue
        assert_ping "spoke$source service reaches spoke$destination service" \
            "spoke$source" "192.168.${source}.1" "192.168.${destination}.1"
    done
done

if capture_output=$("$REPO_ROOT/labs/debug-dmvpn-phase1/capture.sh" healthy 2>&1); then
    pass 'bounded packet evidence proves both hub GRE legs and no direct spoke leg'
else
    fail 'bounded packet evidence proves both hub GRE legs and no direct spoke leg' \
        "${capture_output//$'\n'/; }"
fi

summary
