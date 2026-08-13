#!/usr/bin/env bash
# Grade the exact healthy native VyOS GRE-over-IPsec state without mutating it.
set -u

usage() {
    cat <<'EOF'
Usage: labs/gre-ipsec/check.sh

Read and grade the complete healthy gre-ipsec deployment. The checker sends
bounded pings to exercise protected counters but does not change configuration.
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
lab_init "gre-ipsec"

container() { printf 'clab-%s-%s\n' "$TOPO_NAME" "$1"; }
safe_node() { docker exec "$(container "$1")" bash -c "$2" 2>/dev/null; }
container_image() { docker inspect --format '{{.Config.Image}}' "$(container "$1")" 2>/dev/null; }
normalized_ipsec() {
    sed -E "s/'//g; s/\"//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        grep '^set vpn ipsec ' | LC_ALL=C sort
}

normalized_selected() {
    local prefix=$1
    sed -E "s/'//g; s/\"//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        awk -v prefix="$prefix" \
            '$0 == prefix || index($0, prefix " ") == 1' | LC_ALL=C sort
}

interface_v4_addresses() {
    local node_name=$1 interface_name=$2
    safe_node "$node_name" "ip -4 -o address show dev $interface_name" | \
        awk '{print $4}' | LC_ALL=C sort
}

flatten_xfrm_blocks() {
    awk '
        function clean(line) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            gsub(/[[:space:]]+/, " ", line)
            return line
        }
        function emit() {
            if (block != "") print block
        }
        /^src[[:space:]]/ {
            emit()
            block = clean($0)
            next
        }
        block != "" && NF {
            block = block " | " clean($0)
        }
        END { emit() }
    '
}

child_record() {
    local expected=$1
    awk -v expected="$expected" '
        function clean(line) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            gsub(/[[:space:]]+/, " ", line)
            return line
        }
        /^[^[:space:]]+-tunnel-[0-9]+[[:space:]]/ {
            if (capture) exit
            capture = ($1 == expected)
        }
        capture && NF {
            if (block == "") block = clean($0)
            else block = block " | " clean($0)
        }
        END { if (block != "") print block }
    '
}

nonempty_count() {
    awk 'NF { count++ } END { print count + 0 }'
}

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

assert_count() {
    local label=$1 value=$2 pattern=$3 expected=$4 count
    count=$(grep -Ec "$pattern" <<<"$value" || true)
    assert_equal "$label" "$count" "$expected"
}

assert_ping_linux() {
    local label=$1 node_name=$2 destination=$3
    if docker exec "$(container "$node_name")" ping -c 2 -W 1 \
        "$destination" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label" "the required path is not forwarding"
    fi
}

assert_ping_vyos() {
    local label=$1 node_name=$2 destination=$3 output
    output=$(vyos_op "$node_name" "ping $destination count 2")
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

assert_equal "gw-a uses native VyOS" "$(container_image gw-a)" 'vyos:local'
assert_equal "gw-b uses native VyOS" "$(container_image gw-b)" 'vyos:local'
for incidental in host-a host-b internet; do
    assert_equal "$incidental uses the incidental Linux image" \
        "$(container_image "$incidental")" 'ops-lab:local'
done

assert_match "gw-a is a live VyOS learned role" \
    "$(vyos_op gw-a 'show version')" 'VyOS'
assert_match "gw-b is a live VyOS learned role" \
    "$(vyos_op gw-b 'show version')" 'VyOS'
for incidental in host-a host-b internet; do
    assert_match "$incidental is an incidental Alpine role" \
        "$(safe_node "$incidental" 'cat /etc/alpine-release')" '^[0-9]+\.[0-9]+'
done

assert_equal "host-a has only its exact LAN address" \
    "$(interface_v4_addresses host-a eth1)" '192.168.1.10/24'
assert_equal "host-b has only its exact LAN address" \
    "$(interface_v4_addresses host-b eth1)" '192.168.2.10/24'
assert_match "host-a has its exact default path" \
    "$(safe_node host-a 'ip -4 route show default')" \
    '^default via 192\.168\.1\.1 dev eth1([[:space:]]|$)'
assert_match "host-b has its exact default path" \
    "$(safe_node host-b 'ip -4 route show default')" \
    '^default via 192\.168\.2\.1 dev eth1([[:space:]]|$)'

assert_equal "gw-a has only its exact LAN address" \
    "$(interface_v4_addresses gw-a eth1)" '192.168.1.1/24'
assert_equal "gw-a has only its exact WAN address" \
    "$(interface_v4_addresses gw-a eth2)" '203.0.113.1/30'
assert_equal "gw-a has only its exact tunnel address" \
    "$(interface_v4_addresses gw-a tun0)" '172.16.0.1/30'
assert_equal "gw-b has only its exact WAN address" \
    "$(interface_v4_addresses gw-b eth1)" '203.0.113.6/30'
assert_equal "gw-b has only its exact LAN address" \
    "$(interface_v4_addresses gw-b eth2)" '192.168.2.1/24'
assert_equal "gw-b has only its exact tunnel address" \
    "$(interface_v4_addresses gw-b tun0)" '172.16.0.2/30'
assert_equal "transit has only the exact Site A /30 address" \
    "$(interface_v4_addresses internet eth1)" '203.0.113.2/30'
assert_equal "transit has only the exact Site B /30 address" \
    "$(interface_v4_addresses internet eth2)" '203.0.113.5/30'
assert_equal "transit IPv4 forwarding is enabled" \
    "$(safe_node internet 'sysctl -n net.ipv4.ip_forward')" '1'

a_config_raw=$(vyos_op gw-a 'show configuration commands')
b_config_raw=$(vyos_op gw-b 'show configuration commands')
a_saved_raw=$(safe_node gw-a '/usr/bin/vyos-config-to-commands /config/config.boot')
b_saved_raw=$(safe_node gw-b '/usr/bin/vyos-config-to-commands /config/config.boot')
a_config=$(tr -d "'\"" <<<"$a_config_raw")
b_config=$(tr -d "'\"" <<<"$b_config_raw")
a_saved=$(tr -d "'\"" <<<"$a_saved_raw")
b_saved=$(tr -d "'\"" <<<"$b_saved_raw")

expected_a_tun0=$(normalized_selected 'set interfaces tunnel tun0' <<'EOF'
set interfaces tunnel tun0 address 172.16.0.1/30
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 remote 203.0.113.6
set interfaces tunnel tun0 source-address 203.0.113.1
EOF
)
expected_b_tun0=$(normalized_selected 'set interfaces tunnel tun0' <<'EOF'
set interfaces tunnel tun0 address 172.16.0.2/30
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 remote 203.0.113.1
set interfaces tunnel tun0 source-address 203.0.113.6
EOF
)
expected_a_remote_lan=$(normalized_selected \
    'set protocols static route 192.168.2.0/24' <<'EOF'
set protocols static route 192.168.2.0/24 next-hop 172.16.0.2
EOF
)
expected_a_peer_wan=$(normalized_selected \
    'set protocols static route 203.0.113.4/30' <<'EOF'
set protocols static route 203.0.113.4/30 next-hop 203.0.113.2
EOF
)
expected_b_remote_lan=$(normalized_selected \
    'set protocols static route 192.168.1.0/24' <<'EOF'
set protocols static route 192.168.1.0/24 next-hop 172.16.0.1
EOF
)
expected_b_peer_wan=$(normalized_selected \
    'set protocols static route 203.0.113.0/30' <<'EOF'
set protocols static route 203.0.113.0/30 next-hop 203.0.113.5
EOF
)

for state_kind in live saved; do
    if [[ "$state_kind" == live ]]; then
        a_state=$a_config
        b_state=$b_config
    else
        a_state=$a_saved
        b_state=$b_saved
    fi
    assert_equal "gw-a complete tun0 subtree is exact in $state_kind state" \
        "$(normalized_selected 'set interfaces tunnel tun0' <<<"$a_state")" \
        "$expected_a_tun0"
    assert_equal "gw-a complete remote-LAN route subtree is exact in $state_kind state" \
        "$(normalized_selected 'set protocols static route 192.168.2.0/24' <<<"$a_state")" \
        "$expected_a_remote_lan"
    assert_equal "gw-a complete peer-WAN route subtree is exact in $state_kind state" \
        "$(normalized_selected 'set protocols static route 203.0.113.4/30' <<<"$a_state")" \
        "$expected_a_peer_wan"
    assert_equal "gw-b complete tun0 subtree is exact in $state_kind state" \
        "$(normalized_selected 'set interfaces tunnel tun0' <<<"$b_state")" \
        "$expected_b_tun0"
    assert_equal "gw-b complete remote-LAN route subtree is exact in $state_kind state" \
        "$(normalized_selected 'set protocols static route 192.168.1.0/24' <<<"$b_state")" \
        "$expected_b_remote_lan"
    assert_equal "gw-b complete peer-WAN route subtree is exact in $state_kind state" \
        "$(normalized_selected 'set protocols static route 203.0.113.0/30' <<<"$b_state")" \
        "$expected_b_peer_wan"
done

a_routes=$(safe_node gw-a 'ip -4 route show')
b_routes=$(safe_node gw-b 'ip -4 route show')
assert_match "gw-a resolves the far WAN through the physical underlay" "$a_routes" \
    '^203\.0\.113\.4/30 .*via 203\.0\.113\.2 dev eth2'
assert_match "gw-b resolves the far WAN through the physical underlay" "$b_routes" \
    '^203\.0\.113\.0/30 .*via 203\.0\.113\.5 dev eth1'
assert_match "gw-a routes the remote LAN through tun0" "$a_routes" \
    '^192\.168\.2\.0/24 .*via 172\.16\.0\.2 dev tun0'
assert_match "gw-b routes the remote LAN through tun0" "$b_routes" \
    '^192\.168\.1\.0/24 .*via 172\.16\.0\.1 dev tun0'

expected_a=$(normalized_ipsec <<'EOF'
set vpn ipsec ike-group GRE-IPSEC key-exchange ikev2
set vpn ipsec ike-group GRE-IPSEC proposal 10 encryption aes256
set vpn ipsec ike-group GRE-IPSEC proposal 10 hash sha256
set vpn ipsec ike-group GRE-IPSEC proposal 10 dh-group 14
set vpn ipsec esp-group GRE-IPSEC mode transport
set vpn ipsec esp-group GRE-IPSEC proposal 10 encryption aes256
set vpn ipsec esp-group GRE-IPSEC proposal 10 hash sha256
set vpn ipsec authentication psk LAB-PSK id 203.0.113.1
set vpn ipsec authentication psk LAB-PSK id 203.0.113.6
set vpn ipsec authentication psk LAB-PSK secret GreIpsecLab123
set vpn ipsec site-to-site peer GW-B remote-address 203.0.113.6
set vpn ipsec site-to-site peer GW-B authentication mode pre-shared-secret
set vpn ipsec site-to-site peer GW-B authentication local-id 203.0.113.1
set vpn ipsec site-to-site peer GW-B authentication remote-id 203.0.113.6
set vpn ipsec site-to-site peer GW-B connection-type initiate
set vpn ipsec site-to-site peer GW-B local-address 203.0.113.1
set vpn ipsec site-to-site peer GW-B ike-group GRE-IPSEC
set vpn ipsec site-to-site peer GW-B default-esp-group GRE-IPSEC
set vpn ipsec site-to-site peer GW-B tunnel 1 protocol gre
EOF
)
expected_b=$(normalized_ipsec <<'EOF'
set vpn ipsec ike-group GRE-IPSEC key-exchange ikev2
set vpn ipsec ike-group GRE-IPSEC proposal 10 encryption aes256
set vpn ipsec ike-group GRE-IPSEC proposal 10 hash sha256
set vpn ipsec ike-group GRE-IPSEC proposal 10 dh-group 14
set vpn ipsec esp-group GRE-IPSEC mode transport
set vpn ipsec esp-group GRE-IPSEC proposal 10 encryption aes256
set vpn ipsec esp-group GRE-IPSEC proposal 10 hash sha256
set vpn ipsec authentication psk LAB-PSK id 203.0.113.1
set vpn ipsec authentication psk LAB-PSK id 203.0.113.6
set vpn ipsec authentication psk LAB-PSK secret GreIpsecLab123
set vpn ipsec site-to-site peer GW-A remote-address 203.0.113.1
set vpn ipsec site-to-site peer GW-A authentication mode pre-shared-secret
set vpn ipsec site-to-site peer GW-A authentication local-id 203.0.113.6
set vpn ipsec site-to-site peer GW-A authentication remote-id 203.0.113.1
set vpn ipsec site-to-site peer GW-A connection-type none
set vpn ipsec site-to-site peer GW-A local-address 203.0.113.6
set vpn ipsec site-to-site peer GW-A ike-group GRE-IPSEC
set vpn ipsec site-to-site peer GW-A default-esp-group GRE-IPSEC
set vpn ipsec site-to-site peer GW-A tunnel 1 protocol gre
EOF
)

assert_equal "gw-a live learned state matches the complete healthy definition" \
    "$(normalized_ipsec <<<"$a_config_raw")" "$expected_a"
assert_equal "gw-b live learned state matches the complete healthy definition" \
    "$(normalized_ipsec <<<"$b_config_raw")" "$expected_b"
assert_equal "gw-a saved learned state matches the complete healthy definition" \
    "$(normalized_ipsec <<<"$a_saved_raw")" "$expected_a"
assert_equal "gw-b saved learned state matches the complete healthy definition" \
    "$(normalized_ipsec <<<"$b_saved_raw")" "$expected_b"

for side in a b; do
    if [[ "$side" == a ]]; then config=$a_config; label=gw-a; else config=$b_config; label=gw-b; fi
    assert_match "$label uses IKEv2" "$config" \
        '^set vpn ipsec ike-group GRE-IPSEC key-exchange ikev2$'
    assert_match "$label IKE encryption is exact" "$config" \
        '^set vpn ipsec ike-group GRE-IPSEC proposal 10 encryption aes256$'
    assert_match "$label IKE hash is exact" "$config" \
        '^set vpn ipsec ike-group GRE-IPSEC proposal 10 hash sha256$'
    assert_match "$label IKE DH group is exact" "$config" \
        '^set vpn ipsec ike-group GRE-IPSEC proposal 10 dh-group 14$'
    assert_match "$label ESP mode is transport" "$config" \
        '^set vpn ipsec esp-group GRE-IPSEC mode transport$'
    assert_match "$label ESP encryption is exact" "$config" \
        '^set vpn ipsec esp-group GRE-IPSEC proposal 10 encryption aes256$'
    assert_match "$label ESP hash is exact" "$config" \
        '^set vpn ipsec esp-group GRE-IPSEC proposal 10 hash sha256$'
    assert_not_match "$label has no fault ESP hash" "$config" \
        '^set vpn ipsec esp-group GRE-IPSEC proposal 10 hash sha512$'
    assert_count "$label has exactly two PSK identities" "$config" \
        '^set vpn ipsec authentication psk LAB-PSK id 203\.0\.113\.(1|6)$' '2'
done

for item in \
    'gw-a remote address|set vpn ipsec site-to-site peer GW-B remote-address 203\.0\.113\.6' \
    'gw-a local identity|set vpn ipsec site-to-site peer GW-B authentication local-id 203\.0\.113\.1' \
    'gw-a remote identity|set vpn ipsec site-to-site peer GW-B authentication remote-id 203\.0\.113\.6' \
    'gw-a initiator role|set vpn ipsec site-to-site peer GW-B connection-type initiate' \
    'gw-a local address|set vpn ipsec site-to-site peer GW-B local-address 203\.0\.113\.1' \
    'gw-a IKE binding|set vpn ipsec site-to-site peer GW-B ike-group GRE-IPSEC' \
    'gw-a ESP binding|set vpn ipsec site-to-site peer GW-B default-esp-group GRE-IPSEC' \
    'gw-a GRE selector|set vpn ipsec site-to-site peer GW-B tunnel 1 protocol gre' \
    'gw-b remote address|set vpn ipsec site-to-site peer GW-A remote-address 203\.0\.113\.1' \
    'gw-b local identity|set vpn ipsec site-to-site peer GW-A authentication local-id 203\.0\.113\.6' \
    'gw-b remote identity|set vpn ipsec site-to-site peer GW-A authentication remote-id 203\.0\.113\.1' \
    'gw-b responder role|set vpn ipsec site-to-site peer GW-A connection-type none' \
    'gw-b local address|set vpn ipsec site-to-site peer GW-A local-address 203\.0\.113\.6' \
    'gw-b IKE binding|set vpn ipsec site-to-site peer GW-A ike-group GRE-IPSEC' \
    'gw-b ESP binding|set vpn ipsec site-to-site peer GW-A default-esp-group GRE-IPSEC' \
    'gw-b GRE selector|set vpn ipsec site-to-site peer GW-A tunnel 1 protocol gre'; do
    label=${item%%|*}
    pattern=${item#*|}
    if [[ "$label" == gw-a* ]]; then state=$a_config; else state=$b_config; fi
    assert_match "$label is exact" "$state" "^${pattern}$"
done

assert_ping_vyos "gw-a reaches its near public next hop" gw-a 203.0.113.2
assert_ping_vyos "gw-b reaches its near public next hop" gw-b 203.0.113.5
assert_ping_vyos "gw-a reaches the remote public endpoint" gw-a 203.0.113.6
assert_ping_vyos "gw-b reaches the remote public endpoint" gw-b 203.0.113.1
assert_ping_vyos "gw-a reaches the remote GRE endpoint" gw-a 172.16.0.2
assert_ping_vyos "gw-b reaches the remote GRE endpoint" gw-b 172.16.0.1
assert_ping_linux "host-a reaches host-b through protected GRE" host-a 192.168.2.10
assert_ping_linux "host-b reaches host-a through protected GRE" host-b 192.168.1.10

a_ike=$(vyos_op gw-a 'show vpn ike sa')
b_ike=$(vyos_op gw-b 'show vpn ike sa')
a_child=$(vyos_op gw-a 'show vpn ipsec sa')
b_child=$(vyos_op gw-b 'show vpn ipsec sa')
a_connections=$(vyos_op gw-a 'show vpn ipsec connections')
b_connections=$(vyos_op gw-b 'show vpn ipsec connections')

for side in a b; do
    if [[ "$side" == a ]]; then
        ike=$a_ike; child=$a_child; label=gw-a; child_name=GW-B-tunnel-1
    else
        ike=$b_ike; child=$b_child; label=gw-b; child_name=GW-A-tunnel-1
    fi
    assert_count "$label has exactly one established IKE SA" "$ike" \
        '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' '1'
    assert_match "$label IKE row is exact" "$ike" \
        '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]+AES_CBC_256[[:space:]]+HMAC_SHA2_256_128[[:space:]]+MODP_2048[[:space:]]+no[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]*$'
    assert_count "$label has exactly one total up child SA" "$child" \
        '^[^[:space:]]+[[:space:]]+up[[:space:]]' '1'
    assert_count "$label expected child is the sole up child" "$child" \
        "^${child_name}[[:space:]]+up[[:space:]]" '1'
    expected_child_record=$(child_record "$child_name" <<<"$child")
    assert_match "$label expected child record uses exact ESP algorithms" \
        "$expected_child_record" \
        'AES_CBC_256/HMAC_SHA2_256_128'
done

# Connection rows expose the WAN /32 selectors with protocol GRE.
assert_match "gw-a connection exposes its exact local GRE selector" "$a_connections" \
    '203\.0\.113\.1/32\[gre\]'
assert_match "gw-a connection exposes its exact remote GRE selector" "$a_connections" \
    '203\.0\.113\.6/32\[gre\]'
assert_match "gw-b connection exposes its exact local GRE selector" "$b_connections" \
    '203\.0\.113\.6/32\[gre\]'
assert_match "gw-b connection exposes its exact remote GRE selector" "$b_connections" \
    '203\.0\.113\.1/32\[gre\]'

a_xfrm_state=$(safe_node gw-a 'ip -s xfrm state')
b_xfrm_state=$(safe_node gw-b 'ip -s xfrm state')
a_xfrm_policy=$(safe_node gw-a 'ip -s xfrm policy')
b_xfrm_policy=$(safe_node gw-b 'ip -s xfrm policy')
for side in a b; do
    if [[ "$side" == a ]]; then
        state=$a_xfrm_state; policy=$a_xfrm_policy; label=gw-a
    else
        state=$b_xfrm_state; policy=$b_xfrm_policy; label=gw-b
    fi
    state_blocks=$(flatten_xfrm_blocks <<<"$state")
    esp_state_blocks=$(grep -E \
        '(^|[[:space:]]\|[[:space:]])proto esp([[:space:]]|$)' \
        <<<"$state_blocks" || true)
    peer_state_blocks=$(grep -E \
        '^src 203\.0\.113\.(1|6) dst 203\.0\.113\.(1|6)([[:space:]]+\||$)' \
        <<<"$state_blocks" || true)
    outbound_state=$(grep -E \
        '^src 203\.0\.113\.1 dst 203\.0\.113\.6([[:space:]]+\||$)' \
        <<<"$peer_state_blocks" || true)
    inbound_state=$(grep -E \
        '^src 203\.0\.113\.6 dst 203\.0\.113\.1([[:space:]]+\||$)' \
        <<<"$peer_state_blocks" || true)

    assert_equal "$label has exactly two total ESP state blocks" \
        "$(nonempty_count <<<"$esp_state_blocks")" '2'
    assert_equal "$label has exactly two public-peer state blocks" \
        "$(nonempty_count <<<"$peer_state_blocks")" '2'
    assert_equal "$label has exactly one outbound public-peer state block" \
        "$(nonempty_count <<<"$outbound_state")" '1'
    assert_equal "$label has exactly one inbound public-peer state block" \
        "$(nonempty_count <<<"$inbound_state")" '1'
    assert_match "$label outbound state itself is ESP transport mode" \
        "$outbound_state" \
        '(^|[[:space:]]\|[[:space:]])proto esp .* mode transport([[:space:]]|$)'
    assert_match "$label outbound state itself has positive current counters" \
        "$outbound_state" \
        'lifetime current:.*[1-9][0-9]*\(bytes\), [1-9][0-9]*\(packets\)'
    assert_match "$label inbound state itself is ESP transport mode" \
        "$inbound_state" \
        '(^|[[:space:]]\|[[:space:]])proto esp .* mode transport([[:space:]]|$)'
    assert_match "$label inbound state itself has positive current counters" \
        "$inbound_state" \
        'lifetime current:.*[1-9][0-9]*\(bytes\), [1-9][0-9]*\(packets\)'

    policy_blocks=$(flatten_xfrm_blocks <<<"$policy")
    gre_policy_blocks=$(grep -E '^src .* proto gre([[:space:]]|$)' \
        <<<"$policy_blocks" || true)
    peer_policy_blocks=$(grep -E \
        '^src 203\.0\.113\.(1|6)/32 dst 203\.0\.113\.(1|6)/32 proto gre uid [0-9]+([[:space:]]+\||$)' \
        <<<"$gre_policy_blocks" || true)
    outbound_policy=$(grep -E \
        '^src 203\.0\.113\.1/32 dst 203\.0\.113\.6/32 proto gre uid [0-9]+([[:space:]]+\||$)' \
        <<<"$peer_policy_blocks" || true)
    inbound_policy=$(grep -E \
        '^src 203\.0\.113\.6/32 dst 203\.0\.113\.1/32 proto gre uid [0-9]+([[:space:]]+\||$)' \
        <<<"$peer_policy_blocks" || true)

    assert_equal "$label has exactly two total GRE selector blocks" \
        "$(nonempty_count <<<"$gre_policy_blocks")" '2'
    assert_equal "$label has exactly two public-peer GRE selector blocks" \
        "$(nonempty_count <<<"$peer_policy_blocks")" '2'
    assert_equal "$label has exactly one outbound GRE selector block" \
        "$(nonempty_count <<<"$outbound_policy")" '1'
    assert_equal "$label has exactly one inbound GRE selector block" \
        "$(nonempty_count <<<"$inbound_policy")" '1'
    assert_match "$label outbound GRE block itself uses ESP transport mode" \
        "$outbound_policy" \
        '(^|[[:space:]]\|[[:space:]])proto esp .* mode transport([[:space:]]|$)'
    assert_match "$label inbound GRE block itself uses ESP transport mode" \
        "$inbound_policy" \
        '(^|[[:space:]]\|[[:space:]])proto esp .* mode transport([[:space:]]|$)'
done

summary
