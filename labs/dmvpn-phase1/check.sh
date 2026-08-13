#!/usr/bin/env bash
# Grade the exact healthy native VyOS DMVPN Phase 1 state.
set -u

usage() {
    cat <<'EOF'
Usage: labs/dmvpn-phase1/check.sh

Read and grade the complete healthy deployment. The checker sends bounded
source-specific pings and runs one bounded GRE path capture, but does not
change configuration.
EOF
}

case ${1:-} in
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac
(( $# == 0 )) || { usage >&2; exit 2; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dmvpn-phase1"

container() { printf 'clab-%s-%s\n' "$TOPO_NAME" "$1"; }
safe_node() { docker exec "$(container "$1")" bash -c "$2" 2>/dev/null; }
container_image() { docker inspect --format '{{.Config.Image}}' "$(container "$1")" 2>/dev/null; }
interface_v4_addresses() {
    safe_node "$1" "ip -4 -o address show dev $2" | awk '{print $4}' | LC_ALL=C sort
}

normalize_commands() {
    sed -E "s/'//g; s/\"//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        LC_ALL=C sort
}

learned_commands() {
    grep -E '^set protocols (nhrp|ospf)([[:space:]]|$)' | normalize_commands
}

assert_equal() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" "observed state differs from the lab contract"
    fi
}

assert_match() {
    local label=$1 actual=$2 pattern=$3
    if grep -qE "$pattern" <<<"$actual"; then
        pass "$label"
    else
        fail "$label" "required correlated state is absent"
    fi
}

assert_not_match() {
    local label=$1 actual=$2 pattern=$3
    if ! grep -qE "$pattern" <<<"$actual"; then
        pass "$label"
    else
        fail "$label" "forbidden shortcut or configuration remains"
    fi
}

assert_count() {
    local label=$1 actual=$2 pattern=$3 expected=$4 count
    count=$(grep -Ec "$pattern" <<<"$actual" || true)
    assert_equal "$label" "$count" "$expected"
}

assert_source_ping() {
    local label=$1 node_name=$2 source=$3 destination=$4
    if timeout 6 docker exec "$(container "$node_name")" ping -I "$source" \
        -c 2 -W 1 "$destination" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label" "bounded source-specific traffic did not reach its destination"
    fi
}

actual_nodes=$(docker ps --format '{{.Names}}' | sed -n \
    "s/^clab-${TOPO_NAME}-//p" | LC_ALL=C sort)
assert_equal "inventory contains exactly the five intended nodes" "$actual_nodes" \
    $'br-wan\nhub\nspoke1\nspoke2\nspoke3'

for router in hub spoke1 spoke2 spoke3; do
    assert_equal "$router uses native VyOS" "$(container_image "$router")" 'vyos:local'
done
assert_equal "incidental WAN bridge uses ops-lab:local" \
    "$(container_image br-wan)" 'ops-lab:local'

bridge_links=$(safe_node br-wan 'bridge link show master br0')
bridge_ports=$(awk '{ port=$2; sub(/:.*/, "", port); sub(/@.*/, "", port); print port }' \
    <<<"$bridge_links" | LC_ALL=C sort)
assert_equal "WAN bridge has exactly four intended member ports" "$bridge_ports" \
    $'eth1\neth2\neth3\neth4'
assert_count "every WAN bridge port is forwarding" "$bridge_links" \
    'master br0 state forwarding' 4
assert_match "WAN bridge interface is operationally up" \
    "$(safe_node br-wan 'ip -o link show dev br0')" 'UP'

declare -A wan=( [hub]=10.0.0.1 [spoke1]=10.0.0.11 [spoke2]=10.0.0.12 [spoke3]=10.0.0.13 )
declare -A tunnel=( [hub]=172.16.0.1 [spoke1]=172.16.0.11 [spoke2]=172.16.0.12 [spoke3]=172.16.0.13 )
for router in hub spoke1 spoke2 spoke3; do
    assert_equal "$router WAN interface has exactly one intended IPv4 address" \
        "$(interface_v4_addresses "$router" eth1)" "${wan[$router]}/24"
    assert_equal "$router tunnel has exactly one intended IPv4 address" \
        "$(interface_v4_addresses "$router" tun0)" "${tunnel[$router]}/32"
    tunnel_link=$(safe_node "$router" 'ip -d link show dev tun0')
    assert_match "$router tunnel is mGRE with no fixed remote" "$tunnel_link" \
        'gre remote any local any dev eth1'
done

for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    assert_equal "$spoke service interface has exactly one intended IPv4 address" \
        "$(interface_v4_addresses "$spoke" dum0)" \
        "192.168.${spoke_number}.1/24"
done

hub_expected=$(cat <<'EOF' | normalize_commands
set protocols nhrp tunnel tun0 holdtime 300
set protocols nhrp tunnel tun0 multicast dynamic
set protocols nhrp tunnel tun0 network-id 1
set protocols nhrp tunnel tun0 registration-no-unique
set protocols ospf area 0 network 172.16.0.1/32
set protocols ospf interface tun0 network point-to-multipoint
set protocols ospf parameters router-id 10.0.0.1
EOF
)

hub_live=$(vyos_op hub 'show configuration commands')
hub_saved=$(safe_node hub '/usr/bin/vyos-config-to-commands /config/config.boot')
assert_equal "hub live NHRP and OSPF scaffold is exact" \
    "$(learned_commands <<<"$hub_live")" "$hub_expected"
assert_equal "hub saved NHRP and OSPF scaffold is exact" \
    "$(learned_commands <<<"$hub_saved")" "$hub_expected"

all_config="$hub_live"
spoke_config=
for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    wan_last=$((10 + spoke_number))
    expected=$(cat <<EOF | normalize_commands
set protocols nhrp tunnel tun0 holdtime 300
set protocols nhrp tunnel tun0 map tunnel-ip 172.16.0.1 nbma 10.0.0.1
set protocols nhrp tunnel tun0 multicast 10.0.0.1
set protocols nhrp tunnel tun0 network-id 1
set protocols nhrp tunnel tun0 nhs tunnel-ip 172.16.0.1 nbma 10.0.0.1
set protocols ospf area 0 network 172.16.0.${wan_last}/32
set protocols ospf area 0 network 192.168.${spoke_number}.0/24
set protocols ospf interface dum0 passive
set protocols ospf interface tun0 network point-to-multipoint
set protocols ospf parameters router-id 10.0.0.${wan_last}
EOF
)
    live=$(vyos_op "$spoke" 'show configuration commands')
    saved=$(safe_node "$spoke" '/usr/bin/vyos-config-to-commands /config/config.boot')
    assert_equal "$spoke live learned state is exact" \
        "$(learned_commands <<<"$live")" "$expected"
    assert_equal "$spoke saved learned state is exact" \
        "$(learned_commands <<<"$saved")" "$expected"
    all_config+=$'\n'"$live"
    spoke_config+=$'\n'"$live"
done

assert_not_match "no redirect, shortcut, or fixed-remote cheat exists" \
    "$all_config" \
    '^set protocols nhrp .*\b(redirect|shortcut)\b|^set interfaces tunnel tun0 remote '
assert_not_match "no spoke bypasses unique NHRP registration" "$spoke_config" \
    '^set protocols nhrp .*\bregistration-no-unique\b'
assert_not_match "no learned-plane static route bypasses OSPF" "$all_config" \
    '^set protocols static route (172\.16\.0\.|192\.168\.)'

hub_nhrp=$(vyos_frr hub 'show ip nhrp')
assert_count "hub NHRP table has exactly four rows" "$hub_nhrp" '^tun0[[:space:]]' 4
assert_match "hub NHRP table has one exact local row" "$hub_nhrp" \
    '^tun0[[:space:]]+local[[:space:]]+172\.16\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+-([[:space:]]|$)'
for spoke_number in 1 2 3; do
    wan_last=$((10 + spoke_number))
    assert_match "hub correlates spoke$spoke_number tunnel and NBMA addresses dynamically" \
        "$hub_nhrp" \
        "^tun0[[:space:]]+dynamic[[:space:]]+172\\.16\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+T([[:space:]]|$)"
done

for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    wan_last=$((10 + spoke_number))
    nhrp=$(vyos_frr "$spoke" 'show ip nhrp')
    assert_count "$spoke NHRP table has exactly two rows" "$nhrp" '^tun0[[:space:]]' 2
    assert_match "$spoke has one exact local NHRP row" "$nhrp" \
        "^tun0[[:space:]]+local[[:space:]]+172\\.16\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+-([[:space:]]|$)"
    assert_match "$spoke has one exact static hub mapping" "$nhrp" \
        '^tun0[[:space:]]+static[[:space:]]+172\.16\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+-([[:space:]]|$)'
    other_pattern='172\.16\.0\.'
    for other in 1 2 3; do
        [[ "$other" == "$spoke_number" ]] && continue
        other_last=$((10 + other))
        assert_not_match "$spoke has no direct spoke$other NHRP shortcut" "$nhrp" \
            "${other_pattern}${other_last}"
    done
done

hub_neighbors=$(vyos_frr hub 'show ip ospf neighbor')
assert_count "hub has exactly three OSPF neighbors" "$hub_neighbors" '^[0-9]+\.' 3
for spoke_number in 1 2 3; do
    wan_last=$((10 + spoke_number))
    assert_match "hub has spoke$spoke_number Full at its correlated tunnel address" \
        "$hub_neighbors" \
        "^10\\.0\\.0\\.${wan_last}[[:space:]].*Full/[^[:space:]]+[[:space:]].*172\\.16\\.0\\.${wan_last}([[:space:]]|$)"
done

for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    neighbors=$(vyos_frr "$spoke" 'show ip ospf neighbor')
    assert_count "$spoke has exactly one OSPF neighbor" "$neighbors" '^[0-9]+\.' 1
    assert_match "$spoke has only the hub Full at 172.16.0.1" "$neighbors" \
        '^10\.0\.0\.1[[:space:]].*Full/[^[:space:]]+[[:space:]].*172\.16\.0\.1([[:space:]]|$)'
done

hub_routes=$(vyos_frr hub 'show ip route ospf')
assert_count "hub learns exactly three remote service prefixes" "$hub_routes" \
    '^O[^[:space:]]*[[:space:]]+192\.168\.[123]\.0/24' 3
for spoke_number in 1 2 3; do
    wan_last=$((10 + spoke_number))
    assert_match "hub routes service LAN $spoke_number through its owning spoke" \
        "$hub_routes" \
        "^O[^[:space:]]*[[:space:]]+192\\.168\\.${spoke_number}\\.0/24.*via 172\\.16\\.0\\.${wan_last}, tun0"
done

for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    routes=$(vyos_frr "$spoke" 'show ip route ospf')
    assert_count "$spoke learns exactly two remote service prefixes" "$routes" \
        '^O>\*[[:space:]]+192\.168\.[123]\.0/24' 2
    for other in 1 2 3; do
        [[ "$other" == "$spoke_number" ]] && continue
        other_last=$((10 + other))
        assert_match "$spoke routes spoke$other service LAN through the hub" "$routes" \
            "^O[^[:space:]]*[[:space:]]+192\\.168\\.${other}\\.0/24.*via 172\\.16\\.0\\.1, tun0"
        assert_match "$spoke learns spoke$other tunnel /32 through the hub" "$routes" \
            "^O[^[:space:]]*[[:space:]]+172\\.16\\.0\\.${other_last}/32.*via 172\\.16\\.0\\.1, tun0"
    done
done

for source in 1 2 3; do
    for destination in 1 2 3; do
        [[ "$source" == "$destination" ]] && continue
        assert_source_ping "spoke$source service source reaches spoke$destination service LAN" \
            "spoke$source" "192.168.${source}.1" "192.168.${destination}.1"
    done
done

if capture_output=$("$REPO_ROOT/labs/dmvpn-phase1/capture-phase1.sh" 2>&1); then
    pass "bounded GRE evidence proves spoke1-to-spoke2 traffic transits the hub"
else
    fail "bounded GRE evidence proves spoke1-to-spoke2 traffic transits the hub" \
        "${capture_output//$'\n'/; }"
fi

summary
