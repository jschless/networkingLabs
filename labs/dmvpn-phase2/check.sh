#!/usr/bin/env bash
# Grade the exact healthy DMVPN compatibility-reference state.
set -u

usage() {
    cat <<'EOF'
Usage: labs/dmvpn-phase2/check.sh

Read and grade the complete preconfigured reference. The checker clears only
ephemeral NHRP shortcut/cache state, sends bounded source-specific traffic to
reseed all directions, and captures one direct GRE path. It never enters
configure mode or changes live/saved configuration.
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
lab_init "dmvpn-phase2"

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

reference_protocol_commands() {
    grep -E '^set protocols (bgp|nhrp|ospf|static)([[:space:]]|$)' | normalize_commands
}

reference_interface_commands() {
    grep -E '^set interfaces (dummy dum0|ethernet eth1|tunnel tun0)([[:space:]]|$)' | \
        normalize_commands
}

shortcut_data_rows() {
    awk '
        {
            row = $0
            sub(/^[[:space:]]+/, "", row)
            sub(/[[:space:]]+$/, "", row)
            if (row == "")
                next

            lower = tolower(row)
            if (lower ~ /^(type|prefix)([[:space:]]+(type|prefix|state|via|identity|nbma|interface))+$/)
                next
            if (lower ~ /^[-=]+([[:space:]]+[-=]+)*$/)
                next
            if (lower ~ /^%?[[:space:]]*no[[:space:]]+((nhrp[[:space:]]+)?shortcuts?([[:space:]]+entries)?|entries)([[:space:]]+(found|configured|present))?[.!]?$/)
                next

            print row
        }
    '
}

assert_equal() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" "observed state differs from the reference contract"
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
        fail "$label" "forbidden or polluted state remains"
    fi
}

assert_count() {
    local label=$1 actual=$2 pattern=$3 expected=$4 count
    count=$(grep -Ec "$pattern" <<<"$actual" || true)
    assert_equal "$label" "$count" "$expected"
}

assert_between() {
    local label=$1 actual=$2 minimum=$3 maximum=$4
    if (( actual >= minimum && actual <= maximum )); then
        pass "$label"
    else
        fail "$label" "observed count $actual is outside $minimum..$maximum"
    fi
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
    assert_match "$router tunnel is mGRE with no fixed remote" \
        "$(safe_node "$router" 'ip -d link show dev tun0')" \
        'gre remote any local any dev eth1'
done

for spoke_number in 1 2 3; do
    assert_equal "spoke$spoke_number service interface has exactly one intended IPv4 address" \
        "$(interface_v4_addresses "spoke$spoke_number" dum0)" \
        "192.168.${spoke_number}.1/24"
done

hub_expected=$(cat <<'EOF' | normalize_commands
set protocols bgp neighbor 172.16.0.11 address-family ipv4-unicast route-reflector-client
set protocols bgp neighbor 172.16.0.11 remote-as 65000
set protocols bgp neighbor 172.16.0.12 address-family ipv4-unicast route-reflector-client
set protocols bgp neighbor 172.16.0.12 remote-as 65000
set protocols bgp neighbor 172.16.0.13 address-family ipv4-unicast route-reflector-client
set protocols bgp neighbor 172.16.0.13 remote-as 65000
set protocols bgp parameters router-id 10.0.0.1
set protocols bgp system-as 65000
set protocols nhrp tunnel tun0 holdtime 300
set protocols nhrp tunnel tun0 multicast dynamic
set protocols nhrp tunnel tun0 network-id 1
set protocols nhrp tunnel tun0 redirect
set protocols nhrp tunnel tun0 registration-no-unique
EOF
)

hub_interfaces_expected=$(cat <<'EOF' | normalize_commands
set interfaces ethernet eth1 address 10.0.0.1/24
set interfaces ethernet eth1 description "WAN NBMA"
set interfaces ethernet eth1 offload gso
set interfaces ethernet eth1 offload sg
set interfaces tunnel tun0 address 172.16.0.1/32
set interfaces tunnel tun0 description "mGRE DMVPN compatibility hub"
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 source-interface eth1
EOF
)

hub_live=$(vyos_op hub 'show configuration commands')
hub_saved=$(safe_node hub '/usr/bin/vyos-config-to-commands /config/config.boot')
assert_equal "hub live protocol reference is exact" \
    "$(reference_protocol_commands <<<"$hub_live")" "$hub_expected"
assert_equal "hub saved protocol reference is exact" \
    "$(reference_protocol_commands <<<"$hub_saved")" "$hub_expected"
assert_equal "hub live learned-interface reference is exact" \
    "$(reference_interface_commands <<<"$hub_live")" "$hub_interfaces_expected"
assert_equal "hub saved learned-interface reference is exact" \
    "$(reference_interface_commands <<<"$hub_saved")" "$hub_interfaces_expected"

all_config=$hub_live
spoke_config=
for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    wan_last=$((10 + spoke_number))
    expected=$(cat <<EOF | normalize_commands
set protocols bgp address-family ipv4-unicast network 192.168.${spoke_number}.0/24
set protocols bgp neighbor 172.16.0.1 address-family ipv4-unicast
set protocols bgp neighbor 172.16.0.1 remote-as 65000
set protocols bgp parameters router-id 10.0.0.${wan_last}
set protocols bgp system-as 65000
set protocols nhrp tunnel tun0 holdtime 300
set protocols nhrp tunnel tun0 multicast 10.0.0.1
set protocols nhrp tunnel tun0 network-id 1
set protocols nhrp tunnel tun0 nhs tunnel-ip 172.16.0.1 nbma 10.0.0.1
set protocols nhrp tunnel tun0 registration-no-unique
set protocols nhrp tunnel tun0 shortcut
set protocols static route 172.16.0.0/24 next-hop 172.16.0.1 distance 250
EOF
)
    interfaces_expected=$(cat <<EOF | normalize_commands
set interfaces dummy dum0 address 192.168.${spoke_number}.1/24
set interfaces dummy dum0 description "Service LAN ${spoke_number}"
set interfaces ethernet eth1 address 10.0.0.${wan_last}/24
set interfaces ethernet eth1 description "WAN NBMA"
set interfaces ethernet eth1 offload gso
set interfaces ethernet eth1 offload sg
set interfaces tunnel tun0 address 172.16.0.${wan_last}/32
set interfaces tunnel tun0 description "mGRE DMVPN compatibility spoke${spoke_number}"
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 source-interface eth1
EOF
)
    live=$(vyos_op "$spoke" 'show configuration commands')
    saved=$(safe_node "$spoke" '/usr/bin/vyos-config-to-commands /config/config.boot')
    assert_equal "$spoke live protocol reference is exact" \
        "$(reference_protocol_commands <<<"$live")" "$expected"
    assert_equal "$spoke saved protocol reference is exact" \
        "$(reference_protocol_commands <<<"$saved")" "$expected"
    assert_equal "$spoke live learned-interface reference is exact" \
        "$(reference_interface_commands <<<"$live")" "$interfaces_expected"
    assert_equal "$spoke saved learned-interface reference is exact" \
        "$(reference_interface_commands <<<"$saved")" "$interfaces_expected"
    all_config+=$'\n'"$live"
    spoke_config+=$'\n'"$live"
done

assert_not_match "no OSPF or fixed-remote Phase 2 simulation remains" "$all_config" \
    '^set protocols ospf|^set interfaces tunnel tun0 remote '
assert_not_match "no service-prefix static route bypasses BGP" "$all_config" \
    '^set protocols static route 192\.168\.'
assert_not_match "no preconfigured remote overlay or service-host map exists" \
    "$spoke_config" \
    "^set protocols nhrp .*map tunnel-ip ['\"]?(172\\.16\\.0\\.1[123]|192\\.168\\.[123]\\.1)['\"]? "

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

hub_bgp=$(vyos_frr hub 'show bgp ipv4 unicast summary')
assert_count "hub has exactly three iBGP peers" "$hub_bgp" \
    '^172\.16\.0\.1[123][[:space:]]' 3
for spoke_number in 1 2 3; do
    wan_last=$((10 + spoke_number))
    assert_match "hub iBGP peer spoke$spoke_number is Established" "$hub_bgp" \
        "^172\\.16\\.0\\.${wan_last}[[:space:]]+4[[:space:]]+65000[[:space:]].*[[:space:]][0-9]+([[:space:]]|$)"
done

for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    summary_output=$(vyos_frr "$spoke" 'show bgp ipv4 unicast summary')
    assert_count "$spoke has exactly one iBGP peer" "$summary_output" \
        '^172\.16\.0\.1[[:space:]]' 1
    assert_match "$spoke hub iBGP peer is Established" "$summary_output" \
        '^172\.16\.0\.1[[:space:]]+4[[:space:]]+65000[[:space:]].*[[:space:]][0-9]+([[:space:]]|$)'

    bgp_table=$(vyos_frr "$spoke" 'show bgp ipv4 unicast')
    for other in 1 2 3; do
        [[ "$other" == "$spoke_number" ]] && continue
        other_last=$((10 + other))
        assert_match "$spoke preserves spoke$other as the BGP next hop" "$bgp_table" \
            "^[*>i[:space:]]*192\\.168\\.${other}\\.0/24[[:space:]]+172\\.16\\.0\\.${other_last}([[:space:]]|$)"
    done
done

shortcuts_seeded=false
if seed_output=$("$REPO_ROOT/labs/dmvpn-phase2/seed-shortcuts.sh" 2>&1); then
    pass "bounded traffic seeds every correlated spoke overlay and direct FIB"
    shortcuts_seeded=true
else
    fail "bounded traffic seeds every correlated spoke overlay and direct FIB" \
        "${seed_output//$'\n'/; }"
fi

for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    nhrp=$(vyos_frr "$spoke" 'show ip nhrp')
    shortcuts=$(vyos_frr "$spoke" 'show ip nhrp shortcut')
    wan_last=$((10 + spoke_number))
    assert_count "$spoke retains exactly one local NHRP row" "$nhrp" \
        "^tun0[[:space:]]+local[[:space:]]+172\\.16\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+-([[:space:]]|$)" \
        1
    assert_count "$spoke retains exactly one NHS hub mapping" "$nhrp" \
        '^tun0[[:space:]]+nhs[[:space:]]+172\.16\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+T([[:space:]]|$)' \
        1

    remote_overlay_alternatives=
    remote_service_alternatives=
    shortcut_alternatives=
    for other in 1 2 3; do
        [[ "$other" == "$spoke_number" ]] && continue
        other_last=$((10 + other))
        [[ -z "$remote_overlay_alternatives" ]] || remote_overlay_alternatives+='|'
        [[ -z "$remote_service_alternatives" ]] || remote_service_alternatives+='|'
        [[ -z "$shortcut_alternatives" ]] || shortcut_alternatives+='|'
        remote_overlay_alternatives+="172\\.16\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}"
        remote_service_alternatives+="192\\.168\\.${other}\\.1[[:space:]]+10\\.0\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}"
        shortcut_alternatives+="192\\.168\\.${other}\\.0/24[[:space:]]+172\\.16\\.0\\.${other_last}"
    done

    nhrp_rows=$(grep -E '^tun0[[:space:]]' <<<"$nhrp" || true)
    allowed_nhrp="^tun0[[:space:]]+(local[[:space:]]+172\\.16\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+-|nhs[[:space:]]+172\\.16\\.0\\.1[[:space:]]+10\\.0\\.0\\.1[[:space:]]+10\\.0\\.0\\.1[[:space:]]+T|dynamic[[:space:]]+(${remote_overlay_alternatives}|${remote_service_alternatives}))([[:space:]]|$)"
    unexpected_nhrp=$(grep -Ev "$allowed_nhrp" <<<"$nhrp_rows" || true)
    assert_equal "$spoke NHRP table contains no unexpected or miscorrelated row" \
        "$unexpected_nhrp" ''
    nhrp_row_count=$(grep -Ec '^tun0[[:space:]]' <<<"$nhrp_rows" || true)
    assert_between "$spoke has four required and at most two optional NHRP rows" \
        "$nhrp_row_count" 4 6
    service_host_count=$(grep -Ec "^tun0[[:space:]]+dynamic[[:space:]]+(${remote_service_alternatives})([[:space:]]|$)" \
        <<<"$nhrp_rows" || true)
    assert_between "$spoke has zero to two correctly correlated service-host rows" \
        "$service_host_count" 0 2

    shortcut_rows=$(shortcut_data_rows <<<"$shortcuts")
    unexpected_shortcuts=$(grep -Ev "^dynamic[[:space:]]+(${shortcut_alternatives})[[:space:]]*$" \
        <<<"$shortcut_rows" || true)
    assert_equal "$spoke shortcut table contains no unexpected or miscorrelated row" \
        "$unexpected_shortcuts" ''
    shortcut_count=$(grep -Ec '^dynamic[[:space:]]' <<<"$shortcut_rows" || true)
    assert_between "$spoke has zero to two correctly correlated service-prefix shortcuts" \
        "$shortcut_count" 0 2

    for other in 1 2 3; do
        [[ "$other" == "$spoke_number" ]] && continue
        other_last=$((10 + other))
        overlay_row_count=$(grep -Ec "^tun0[[:space:]]+dynamic[[:space:]]+172\\.16\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}([[:space:]]|$)" \
            <<<"$nhrp" || true)
        assert_equal "$spoke has exactly one spoke$other overlay mapping" \
            "$overlay_row_count" 1
        service_host_row_count=$(grep -Ec "^tun0[[:space:]]+dynamic[[:space:]]+192\\.168\\.${other}\\.1[[:space:]]+10\\.0\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}([[:space:]]|$)" \
            <<<"$nhrp" || true)
        assert_between "$spoke has at most one correlated spoke$other service-host row" \
            "$service_host_row_count" 0 1
        shortcut_row_count=$(grep -Ec "^dynamic[[:space:]]+192\\.168\\.${other}\\.0/24[[:space:]]+172\\.16\\.0\\.${other_last}[[:space:]]*$" \
            <<<"$shortcut_rows" || true)
        assert_between "$spoke has at most one correlated spoke$other service-prefix shortcut" \
            "$shortcut_row_count" 0 1
        fib=$(safe_node "$spoke" "ip -4 route get 192.168.${other}.1 from 192.168.${spoke_number}.1")
        assert_match "$spoke resolves spoke$other service traffic directly on tun0" \
            "$fib" "^192\\.168\\.${other}\\.1 from 192\\.168\\.${spoke_number}\\.1 (via 172\\.16\\.0\\.${other_last} )?dev tun0([[:space:]]|$)"
    done
done

for source in 1 2 3; do
    for destination in 1 2 3; do
        [[ "$source" == "$destination" ]] && continue
        assert_source_ping "spoke$source service source reaches spoke$destination service LAN" \
            "spoke$source" "192.168.${source}.1" "192.168.${destination}.1"
    done
done

if [[ "$shortcuts_seeded" == true ]]; then
    if capture_output=$("$REPO_ROOT/labs/dmvpn-phase2/capture-shortcut.sh" 2>&1); then
        pass "bridge-wide GRE evidence proves direct spoke1-to-spoke2 forwarding"
    else
        fail "bridge-wide GRE evidence proves direct spoke1-to-spoke2 forwarding" \
            "${capture_output//$'\n'/; }"
    fi
else
    fail "bridge-wide GRE evidence proves direct spoke1-to-spoke2 forwarding" \
        "shortcut seeding failed, so direct capture was skipped"
fi

summary
