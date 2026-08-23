#!/usr/bin/env bash
# Grade the exact healthy native VyOS DMVPN Phase 3 state.
set -u

usage() {
    cat <<'EOF'
Usage: labs/dmvpn-phase3/check.sh

Read and grade the complete healthy deployment. The checker resets only
ephemeral NHRP state, proves the pre-traffic summarized path, sends bounded
source-specific traffic, and captures one direct GRE path. It never changes
live or saved configuration.
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
lab_init "dmvpn-phase3"

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

learned_protocol_commands() {
    grep -E '^set protocols (bgp|nhrp|ospf|static)([[:space:]]|$)' | normalize_commands
}

learned_interface_commands() {
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

external_lsa_facts() {
    awk '
        /^[[:space:]]*LS Type:/ { print "type " $3 }
        /^[[:space:]]*Link State ID:/ { print "id " $4 }
        /^[[:space:]]*Advertising Router:/ { print "advertiser " $3 }
        /^[[:space:]]*Network Mask:/ { print "mask " $3 }
        /^[[:space:]]*Metric Type:/ { print "metric-type " $3 }
    ' | LC_ALL=C sort
}

assert_equal() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" "observed state differs from the Phase 3 contract"
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
set protocols nhrp tunnel tun0 holdtime 300
set protocols nhrp tunnel tun0 multicast dynamic
set protocols nhrp tunnel tun0 network-id 1
set protocols nhrp tunnel tun0 redirect
set protocols nhrp tunnel tun0 registration-no-unique
set protocols ospf area 0 network 172.16.0.1/32
set protocols ospf interface eth1 passive
set protocols ospf interface tun0 network point-to-multipoint
set protocols ospf parameters router-id 10.0.0.1
set protocols ospf redistribute static
set protocols ospf summary-address 192.168.0.0/16
set protocols static route 192.168.1.0/24 next-hop 172.16.0.11
set protocols static route 192.168.2.0/24 next-hop 172.16.0.12
set protocols static route 192.168.3.0/24 next-hop 172.16.0.13
EOF
)

hub_interfaces_expected=$(cat <<'EOF' | normalize_commands
set interfaces ethernet eth1 address 10.0.0.1/24
set interfaces ethernet eth1 description "WAN NBMA"
set interfaces ethernet eth1 offload gso
set interfaces ethernet eth1 offload sg
set interfaces tunnel tun0 address 172.16.0.1/32
set interfaces tunnel tun0 description "mGRE DMVPN Phase 3 hub"
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 source-interface eth1
EOF
)

hub_live=$(vyos_op hub 'show configuration commands')
hub_saved=$(safe_node hub '/usr/bin/vyos-config-to-commands /config/config.boot')
assert_equal "hub live learned protocol reference is exact" \
    "$(learned_protocol_commands <<<"$hub_live")" "$hub_expected"
assert_equal "hub saved learned protocol reference is exact" \
    "$(learned_protocol_commands <<<"$hub_saved")" "$hub_expected"
assert_equal "hub live learned-interface reference is exact" \
    "$(learned_interface_commands <<<"$hub_live")" "$hub_interfaces_expected"
assert_equal "hub saved learned-interface reference is exact" \
    "$(learned_interface_commands <<<"$hub_saved")" "$hub_interfaces_expected"

all_config=$hub_live
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
set protocols nhrp tunnel tun0 registration-no-unique
set protocols nhrp tunnel tun0 shortcut
set protocols ospf area 0 network 172.16.0.${wan_last}/32
set protocols ospf interface tun0 network point-to-multipoint
set protocols ospf parameters router-id 10.0.0.${wan_last}
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
set interfaces tunnel tun0 description "mGRE DMVPN Phase 3 spoke${spoke_number}"
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 source-interface eth1
EOF
)
    live=$(vyos_op "$spoke" 'show configuration commands')
    saved=$(safe_node "$spoke" '/usr/bin/vyos-config-to-commands /config/config.boot')
    assert_equal "$spoke live learned protocol state is exact" \
        "$(learned_protocol_commands <<<"$live")" "$expected"
    assert_equal "$spoke saved learned protocol state is exact" \
        "$(learned_protocol_commands <<<"$saved")" "$expected"
    assert_equal "$spoke live learned-interface state is exact" \
        "$(learned_interface_commands <<<"$live")" "$interfaces_expected"
    assert_equal "$spoke saved learned-interface state is exact" \
        "$(learned_interface_commands <<<"$saved")" "$interfaces_expected"
    all_config+=$'\n'"$live"
    spoke_config+=$'\n'"$live"
done

assert_not_match "no BGP bypass is configured anywhere" "$all_config" \
    '^set protocols bgp([[:space:]]|$)'
assert_not_match "spokes do not advertise service LANs into the shared OSPF area" \
    "$spoke_config" '^set protocols ospf area .*network 192\.168\.'
assert_not_match "no spoke service static route bypasses the hub summary" \
    "$spoke_config" '^set protocols static route 192\.168\.'
assert_not_match "no spoke preconfigures a remote overlay or service-host map" \
    "$spoke_config" \
    "^set protocols nhrp .*map tunnel-ip ['\"]?(172\\.16\\.0\\.1[123]|192\\.168\\.[123]\\.1)['\"]? "
assert_not_match "no fixed-remote tunnel simulates mGRE" "$all_config" \
    '^set interfaces tunnel tun0 remote '

hub_nhrp=$(vyos_frr hub 'show ip nhrp')
assert_count "hub NHRP table has exactly four rows" "$hub_nhrp" '^tun0[[:space:]]' 4
assert_match "hub NHRP table has one exact local row" "$hub_nhrp" \
    '^tun0[[:space:]]+local[[:space:]]+172\.16\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+10\.0\.0\.1[[:space:]]+-([[:space:]]|$)'
for spoke_number in 1 2 3; do
    wan_last=$((10 + spoke_number))
    assert_match "hub correlates spoke$spoke_number tunnel and NBMA registration" \
        "$hub_nhrp" \
        "^tun0[[:space:]]+dynamic[[:space:]]+172\\.16\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+T([[:space:]]|$)"
done

hub_neighbors=$(vyos_frr hub 'show ip ospf neighbor')
assert_count "hub has exactly three OSPF neighbors" "$hub_neighbors" '^[0-9]+\.' 3
for spoke_number in 1 2 3; do
    wan_last=$((10 + spoke_number))
    assert_match "hub has spoke$spoke_number Full at its correlated overlay address" \
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

hub_static=$(vyos_frr hub 'show ip route static')
for spoke_number in 1 2 3; do
    wan_last=$((10 + spoke_number))
    assert_match "hub owns service LAN $spoke_number through its exact spoke overlay" \
        "$hub_static" \
        "^S[^[:space:]]*[[:space:]]+192\\.168\\.${spoke_number}\\.0/24.*via 172\\.16\\.0\\.${wan_last}, tun0"
    hub_fib=$(safe_node hub "ip -4 route get 192.168.${spoke_number}.1")
    assert_match "hub FIB resolves service LAN $spoke_number through spoke$spoke_number" \
        "$hub_fib" \
        "^192\\.168\\.${spoke_number}\\.1 via 172\\.16\\.0\\.${wan_last} dev tun0([[:space:]]|$)"
done

reset_ok=true
for source in 1 2 3; do
    timeout 10 docker exec "$(container "spoke$source")" vtysh \
        -c 'clear ip nhrp shortcut' -c 'clear ip nhrp cache' >/dev/null 2>&1 || reset_ok=false
done
if [[ "$reset_ok" == true ]]; then
    pass "ephemeral NHRP shortcut and cache state resets without configuration changes"
else
    fail "ephemeral NHRP shortcut and cache state resets without configuration changes" \
        "one or more bounded operational clears failed"
fi

# Let the configured NHS/local rows and OSPF-only summary settle without
# service traffic. This creates the deterministic before-traffic observation.
sleep 2
for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    wan_last=$((10 + spoke_number))
    nhrp=$(vyos_frr "$spoke" 'show ip nhrp')
    shortcuts=$(shortcut_data_rows <<<"$(vyos_frr "$spoke" 'show ip nhrp shortcut')")
    assert_match "$spoke pre-traffic NHRP table retains its exact local row" "$nhrp" \
        "^tun0[[:space:]]+local[[:space:]]+172\\.16\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+-([[:space:]]|$)"
    assert_match "$spoke pre-traffic NHRP table retains the exact hub mapping" "$nhrp" \
        '^tun0[[:space:]]+(static|nhs)[[:space:]]+172\.16\.0\.1[[:space:]]+10\.0\.0\.1([[:space:]]+10\.0\.0\.1)?[[:space:]]+[-T]([[:space:]]|$)'
    assert_equal "$spoke pre-traffic shortcut table is empty" "$shortcuts" ''

    ospf_routes=$(vyos_frr "$spoke" 'show ip route ospf')
    assert_count "$spoke has exactly one summarized OSPF service route" \
        "$ospf_routes" '^O>\*[[:space:]]+192\.168\.0\.0/16' 1
    assert_match "$spoke service summary initially resolves through the hub" \
        "$ospf_routes" '^O>\*[[:space:]]+192\.168\.0\.0/16.*via 172\.16\.0\.1, tun0'
    external_lsa=$(vyos_frr "$spoke" 'show ip ospf database external')
    assert_equal "$spoke has exactly one hub-originated Type-2 external /16 LSA" \
        "$(external_lsa_facts <<<"$external_lsa")" \
        $'advertiser 10.0.0.1\nid 192.168.0.0\nmask /16\nmetric-type 2\ntype AS-external-LSA'
    remote_specific_pattern='^O.*192\.168\.('
    remote_alternatives=
    for other in 1 2 3; do
        [[ "$other" == "$spoke_number" ]] && continue
        [[ -z "$remote_alternatives" ]] || remote_alternatives+='|'
        remote_alternatives+="$other"
    done
    remote_specific_pattern+="${remote_alternatives})\\.(0/24|1/32)"
    assert_not_match "$spoke has no remote OSPF service /24 or /32" \
        "$ospf_routes" "$remote_specific_pattern"

    for other in 1 2 3; do
        [[ "$other" == "$spoke_number" ]] && continue
        other_last=$((10 + other))
        assert_match "$spoke learns spoke$other overlay /32 through the hub" \
            "$ospf_routes" \
            "^O[^[:space:]]*[[:space:]]+172\\.16\\.0\\.${other_last}/32.*via 172\\.16\\.0\\.1, tun0"
        initial_fib=$(safe_node "$spoke" \
            "ip -4 route get 192.168.${other}.1 from 192.168.${spoke_number}.1")
        assert_match "$spoke initial service FIB for spoke$other uses the hub" \
            "$initial_fib" \
            "^192\\.168\\.${other}\\.1 from 192\\.168\\.${spoke_number}\\.1 via 172\\.16\\.0\\.1 dev tun0([[:space:]]|$)"
    done
done

shortcuts_seeded=false
if seed_output=$("$REPO_ROOT/labs/dmvpn-phase3/seed-shortcuts.sh" 2>&1); then
    pass "bounded traffic seeds all six service-host mappings, service-prefix shortcuts, and direct FIBs"
    shortcuts_seeded=true
else
    fail "bounded traffic seeds all six service-host mappings, service-prefix shortcuts, and direct FIBs" \
        "${seed_output//$'\n'/; }"
fi

for spoke_number in 1 2 3; do
    spoke="spoke$spoke_number"
    wan_last=$((10 + spoke_number))
    nhrp=$(vyos_frr "$spoke" 'show ip nhrp')
    shortcut_rows=$(shortcut_data_rows <<<"$(vyos_frr "$spoke" 'show ip nhrp shortcut')")

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
    allowed_nhrp="^tun0[[:space:]]+(local[[:space:]]+172\\.16\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+10\\.0\\.0\\.${wan_last}[[:space:]]+-|(static|nhs)[[:space:]]+172\\.16\\.0\\.1[[:space:]]+10\\.0\\.0\\.1([[:space:]]+10\\.0\\.0\\.1)?[[:space:]]+[-T]|dynamic[[:space:]]+(${remote_overlay_alternatives}|${remote_service_alternatives}))([[:space:]]|$)"
    unexpected_nhrp=$(grep -Ev "$allowed_nhrp" <<<"$nhrp_rows" || true)
    assert_equal "$spoke NHRP table contains no unexpected or miscorrelated row" \
        "$unexpected_nhrp" ''
    assert_count "$spoke has exactly six local, hub, overlay, and service-host rows" \
        "$nhrp_rows" '^tun0[[:space:]]' 6

    unexpected_shortcuts=$(grep -Ev \
        "^dynamic[[:space:]]+(${shortcut_alternatives})[[:space:]]*$" \
        <<<"$shortcut_rows" || true)
    assert_equal "$spoke shortcut table contains no unexpected or miscorrelated row" \
        "$unexpected_shortcuts" ''
    assert_count "$spoke has exactly two current-image service-prefix /24 shortcuts" \
        "$shortcut_rows" '^dynamic[[:space:]]' 2

    for other in 1 2 3; do
        [[ "$other" == "$spoke_number" ]] && continue
        other_last=$((10 + other))
        assert_count "$spoke has exactly one spoke$other overlay mapping" "$nhrp" \
            "^tun0[[:space:]]+dynamic[[:space:]]+172\\.16\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}([[:space:]]|$)" 1
        assert_count "$spoke has exactly one spoke$other service-host mapping" "$nhrp" \
            "^tun0[[:space:]]+dynamic[[:space:]]+192\\.168\\.${other}\\.1[[:space:]]+10\\.0\\.0\\.${other_last}[[:space:]]+10\\.0\\.0\\.${other_last}([[:space:]]|$)" 1
        assert_count "$spoke has exactly one spoke$other service-prefix /24 shortcut" \
            "$shortcut_rows" \
            "^dynamic[[:space:]]+192\\.168\\.${other}\\.0/24[[:space:]]+172\\.16\\.0\\.${other_last}[[:space:]]*$" 1
        fib=$(safe_node "$spoke" \
            "ip -4 route get 192.168.${other}.1 from 192.168.${spoke_number}.1")
        assert_match "$spoke resolves spoke$other service traffic directly on tun0" \
            "$fib" \
            "^192\\.168\\.${other}\\.1 from 192\\.168\\.${spoke_number}\\.1 (via 172\\.16\\.0\\.${other_last} )?dev tun0([[:space:]]|$)"
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
    if capture_output=$("$REPO_ROOT/labs/dmvpn-phase3/capture-shortcut.sh" 2>&1); then
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
