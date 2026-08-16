#!/usr/bin/env bash
# Grade the exact healthy native VyOS IPsec state without changing configuration.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "ipsec-basics"

container() { printf 'clab-%s-%s\n' "$TOPO_NAME" "$1"; }
safe_node() { docker exec "$(container "$1")" bash -c "$2" 2>/dev/null; }
container_image() { docker inspect --format '{{.Config.Image}}' "$(container "$1")" 2>/dev/null; }
normalized_ipsec() {
    sed -E "s/'//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        grep '^set vpn ipsec ' | LC_ALL=C sort
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

assert_command() {
    local label=$1 node_name=$2 command=$3
    if safe_node "$node_name" "$command" >/dev/null; then
        pass "$label"
    else
        fail "$label" "required node-local invariant is absent"
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

assert_ping_vyos() {
    local label=$1 node_name=$2 destination=$3 output
    output=$(vyos_op "$node_name" "ping $destination count 2")
    if grep -qE '0% packet loss|bytes from' <<<"$output"; then
        pass "$label"
    else
        fail "$label" "the required underlay path is not forwarding"
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

a_addresses=$(safe_node gw-a 'ip -4 -o address show')
b_addresses=$(safe_node gw-b 'ip -4 -o address show')
internet_addresses=$(safe_node internet 'ip -4 -o address show')
assert_match "gw-a has its exact LAN address" "$a_addresses" \
    'eth1[[:space:]]+inet 192\.168\.1\.1/24'
assert_match "gw-a has its exact WAN address" "$a_addresses" \
    'eth2[[:space:]]+inet 203\.0\.113\.1/30'
assert_match "gw-b has its exact WAN address" "$b_addresses" \
    'eth1[[:space:]]+inet 203\.0\.113\.6/30'
assert_match "gw-b has its exact LAN address" "$b_addresses" \
    'eth2[[:space:]]+inet 192\.168\.2\.1/24'
assert_match "transit has the Site A /30 address" "$internet_addresses" \
    'eth1[[:space:]]+inet 203\.0\.113\.2/30'
assert_match "transit has the Site B /30 address" "$internet_addresses" \
    'eth2[[:space:]]+inet 203\.0\.113\.5/30'

a_routes=$(safe_node gw-a 'ip -4 route show')
b_routes=$(safe_node gw-b 'ip -4 route show')
assert_match "gw-a has the public peer underlay route" "$a_routes" \
    '^203\.0\.113\.4/30 .*via 203\.0\.113\.2 dev eth2'
assert_match "gw-b has the public peer underlay route" "$b_routes" \
    '^203\.0\.113\.0/30 .*via 203\.0\.113\.5 dev eth1'
assert_match "gw-a has a routed policy-selector path" "$a_routes" \
    '^192\.168\.2\.0/24 .*via 203\.0\.113\.2 dev eth2'
assert_match "gw-b has a routed policy-selector path" "$b_routes" \
    '^192\.168\.1\.0/24 .*via 203\.0\.113\.5 dev eth1'

assert_equal "transit IPv4 forwarding is enabled" \
    "$(safe_node internet 'sysctl -n net.ipv4.ip_forward')" '1'
assert_command "transit explicitly accepts established public flows" internet \
    "iptables -w 1 -C FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment IPSEC_PUBLIC_ESTABLISHED -j ACCEPT"
assert_command "transit explicitly accepts public ESP" internet \
    "iptables -w 1 -C FORWARD -p esp -s 203.0.113.0/24 -d 203.0.113.0/24 -m comment --comment IPSEC_PUBLIC_ESP -j ACCEPT"
assert_command "transit drops clear-text private sources" internet \
    "iptables -w 1 -C FORWARD -s 192.168.0.0/16 -m comment --comment IPSEC_BLOCK_PRIVATE_SOURCE -j DROP"
assert_command "transit drops clear-text private destinations" internet \
    "iptables -w 1 -C FORWARD -d 192.168.0.0/16 -m comment --comment IPSEC_BLOCK_PRIVATE_DESTINATION -j DROP"
assert_command "transit explicitly accepts the public underlay" internet \
    "iptables -w 1 -C FORWARD -s 203.0.113.0/24 -d 203.0.113.0/24 -m comment --comment IPSEC_PUBLIC_UNDERLAY -j ACCEPT"
assert_equal "transit default FORWARD policy is DROP" \
    "$(safe_node internet "iptables -S FORWARD | sed -n 's/^-P FORWARD //p'")" 'DROP'
transit_rules=$(safe_node internet 'iptables -S FORWARD')
assert_equal "transit has exactly five ordered policy rules" \
    "$(grep -c '^-A FORWARD ' <<<"$transit_rules" || true)" '5'
established_line=$(grep -n 'IPSEC_PUBLIC_ESTABLISHED' <<<"$transit_rules" | cut -d: -f1)
esp_line=$(grep -n 'IPSEC_PUBLIC_ESP' <<<"$transit_rules" | cut -d: -f1)
source_drop_line=$(grep -n 'IPSEC_BLOCK_PRIVATE_SOURCE' <<<"$transit_rules" | cut -d: -f1)
destination_drop_line=$(grep -n 'IPSEC_BLOCK_PRIVATE_DESTINATION' <<<"$transit_rules" | cut -d: -f1)
underlay_line=$(grep -n 'IPSEC_PUBLIC_UNDERLAY' <<<"$transit_rules" | cut -d: -f1)
if [[ "$established_line" =~ ^[0-9]+$ && "$esp_line" =~ ^[0-9]+$ \
    && "$source_drop_line" =~ ^[0-9]+$ && "$destination_drop_line" =~ ^[0-9]+$ \
    && "$underlay_line" =~ ^[0-9]+$ \
    && "$established_line" -lt "$esp_line" \
    && "$esp_line" -lt "$source_drop_line" \
    && "$source_drop_line" -lt "$destination_drop_line" \
    && "$destination_drop_line" -lt "$underlay_line" ]]; then
    pass "transit policy order permits ESP before blocking private clear text"
else
    fail "transit policy order permits ESP before blocking private clear text" \
        "FORWARD rule order is not deterministic"
fi

a_config_raw=$(vyos_op gw-a 'show configuration commands')
b_config_raw=$(vyos_op gw-b 'show configuration commands')
a_config=$(tr -d "'" <<<"$a_config_raw")
b_config=$(tr -d "'" <<<"$b_config_raw")

expected_a=$(normalized_ipsec <<'EOF'
set vpn ipsec ike-group SITE-TO-SITE key-exchange ikev2
set vpn ipsec ike-group SITE-TO-SITE proposal 10 encryption aes256
set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash sha256
set vpn ipsec ike-group SITE-TO-SITE proposal 10 dh-group 14
set vpn ipsec esp-group SITE-TO-SITE mode tunnel
set vpn ipsec esp-group SITE-TO-SITE proposal 10 encryption aes256
set vpn ipsec esp-group SITE-TO-SITE proposal 10 hash sha256
set vpn ipsec authentication psk LAB-PSK id 203.0.113.1
set vpn ipsec authentication psk LAB-PSK id 203.0.113.6
set vpn ipsec authentication psk LAB-PSK secret LabSecret123
set vpn ipsec site-to-site peer GW-B remote-address 203.0.113.6
set vpn ipsec site-to-site peer GW-B authentication mode pre-shared-secret
set vpn ipsec site-to-site peer GW-B authentication local-id 203.0.113.1
set vpn ipsec site-to-site peer GW-B authentication remote-id 203.0.113.6
set vpn ipsec site-to-site peer GW-B connection-type initiate
set vpn ipsec site-to-site peer GW-B local-address 203.0.113.1
set vpn ipsec site-to-site peer GW-B ike-group SITE-TO-SITE
set vpn ipsec site-to-site peer GW-B default-esp-group SITE-TO-SITE
set vpn ipsec site-to-site peer GW-B tunnel 1 local prefix 192.168.1.0/24
set vpn ipsec site-to-site peer GW-B tunnel 1 remote prefix 192.168.2.0/24
EOF
)
expected_b=$(normalized_ipsec <<'EOF'
set vpn ipsec ike-group SITE-TO-SITE key-exchange ikev2
set vpn ipsec ike-group SITE-TO-SITE proposal 10 encryption aes256
set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash sha256
set vpn ipsec ike-group SITE-TO-SITE proposal 10 dh-group 14
set vpn ipsec esp-group SITE-TO-SITE mode tunnel
set vpn ipsec esp-group SITE-TO-SITE proposal 10 encryption aes256
set vpn ipsec esp-group SITE-TO-SITE proposal 10 hash sha256
set vpn ipsec authentication psk LAB-PSK id 203.0.113.1
set vpn ipsec authentication psk LAB-PSK id 203.0.113.6
set vpn ipsec authentication psk LAB-PSK secret LabSecret123
set vpn ipsec site-to-site peer GW-A remote-address 203.0.113.1
set vpn ipsec site-to-site peer GW-A authentication mode pre-shared-secret
set vpn ipsec site-to-site peer GW-A authentication local-id 203.0.113.6
set vpn ipsec site-to-site peer GW-A authentication remote-id 203.0.113.1
set vpn ipsec site-to-site peer GW-A connection-type none
set vpn ipsec site-to-site peer GW-A local-address 203.0.113.6
set vpn ipsec site-to-site peer GW-A ike-group SITE-TO-SITE
set vpn ipsec site-to-site peer GW-A default-esp-group SITE-TO-SITE
set vpn ipsec site-to-site peer GW-A tunnel 1 local prefix 192.168.2.0/24
set vpn ipsec site-to-site peer GW-A tunnel 1 remote prefix 192.168.1.0/24
EOF
)

assert_equal "gw-a live learned state matches the complete healthy definition" \
    "$(normalized_ipsec <<<"$a_config_raw")" "$expected_a"
assert_equal "gw-b live learned state matches the complete healthy definition" \
    "$(normalized_ipsec <<<"$b_config_raw")" "$expected_b"
saved_a=$(safe_node gw-a '/usr/bin/vyos-config-to-commands /config/config.boot')
saved_b=$(safe_node gw-b '/usr/bin/vyos-config-to-commands /config/config.boot')
assert_equal "gw-a saved learned state matches the complete healthy definition" \
    "$(normalized_ipsec <<<"$saved_a")" "$expected_a"
assert_equal "gw-b saved learned state matches the complete healthy definition" \
    "$(normalized_ipsec <<<"$saved_b")" "$expected_b"

for side in a b; do
    if [[ "$side" == a ]]; then config=$a_config; label=gw-a; else config=$b_config; label=gw-b; fi
    assert_match "$label uses IKEv2" "$config" \
        '^set vpn ipsec ike-group SITE-TO-SITE key-exchange ikev2$'
    assert_match "$label IKE encryption is exact" "$config" \
        '^set vpn ipsec ike-group SITE-TO-SITE proposal 10 encryption aes256$'
    assert_match "$label IKE hash is exact" "$config" \
        '^set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash sha256$'
    assert_not_match "$label has no fault IKE hash" "$config" \
        '^set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash sha512$'
    assert_match "$label IKE DH group is exact" "$config" \
        '^set vpn ipsec ike-group SITE-TO-SITE proposal 10 dh-group 14$'
    assert_match "$label ESP mode is tunnel" "$config" \
        '^set vpn ipsec esp-group SITE-TO-SITE mode tunnel$'
    assert_match "$label ESP encryption is exact" "$config" \
        '^set vpn ipsec esp-group SITE-TO-SITE proposal 10 encryption aes256$'
    assert_match "$label ESP hash is exact" "$config" \
        '^set vpn ipsec esp-group SITE-TO-SITE proposal 10 hash sha256$'
    assert_count "$label has exactly two PSK identities" "$config" \
        '^set vpn ipsec authentication psk LAB-PSK id 203\.0\.113\.(1|6)$' '2'
done

if grep -qx "set vpn ipsec authentication psk LAB-PSK secret 'LabSecret123'" \
    <<<"$a_config_raw"; then
    pass "gw-a has the exact live PSK without disclosing it"
else
    fail "gw-a has the exact live PSK without disclosing it" "secret mismatch"
fi
if grep -qx "set vpn ipsec authentication psk LAB-PSK secret 'LabSecret123'" \
    <<<"$b_config_raw"; then
    pass "gw-b has the exact live PSK without disclosing it"
else
    fail "gw-b has the exact live PSK without disclosing it" "secret mismatch"
fi

for item in \
    'gw-a remote address|set vpn ipsec site-to-site peer GW-B remote-address 203\.0\.113\.6' \
    'gw-a authentication mode|set vpn ipsec site-to-site peer GW-B authentication mode pre-shared-secret' \
    'gw-a local identity|set vpn ipsec site-to-site peer GW-B authentication local-id 203\.0\.113\.1' \
    'gw-a remote identity|set vpn ipsec site-to-site peer GW-B authentication remote-id 203\.0\.113\.6' \
    'gw-a initiator role|set vpn ipsec site-to-site peer GW-B connection-type initiate' \
    'gw-a local address|set vpn ipsec site-to-site peer GW-B local-address 203\.0\.113\.1' \
    'gw-a IKE group binding|set vpn ipsec site-to-site peer GW-B ike-group SITE-TO-SITE' \
    'gw-a ESP group binding|set vpn ipsec site-to-site peer GW-B default-esp-group SITE-TO-SITE' \
    'gw-a local selector|set vpn ipsec site-to-site peer GW-B tunnel 1 local prefix 192\.168\.1\.0/24' \
    'gw-a remote selector|set vpn ipsec site-to-site peer GW-B tunnel 1 remote prefix 192\.168\.2\.0/24' \
    'gw-b remote address|set vpn ipsec site-to-site peer GW-A remote-address 203\.0\.113\.1' \
    'gw-b authentication mode|set vpn ipsec site-to-site peer GW-A authentication mode pre-shared-secret' \
    'gw-b local identity|set vpn ipsec site-to-site peer GW-A authentication local-id 203\.0\.113\.6' \
    'gw-b remote identity|set vpn ipsec site-to-site peer GW-A authentication remote-id 203\.0\.113\.1' \
    'gw-b responder role|set vpn ipsec site-to-site peer GW-A connection-type none' \
    'gw-b local address|set vpn ipsec site-to-site peer GW-A local-address 203\.0\.113\.6' \
    'gw-b IKE group binding|set vpn ipsec site-to-site peer GW-A ike-group SITE-TO-SITE' \
    'gw-b ESP group binding|set vpn ipsec site-to-site peer GW-A default-esp-group SITE-TO-SITE' \
    'gw-b local selector|set vpn ipsec site-to-site peer GW-A tunnel 1 local prefix 192\.168\.2\.0/24' \
    'gw-b remote selector|set vpn ipsec site-to-site peer GW-A tunnel 1 remote prefix 192\.168\.1\.0/24'; do
    label=${item%%|*}
    pattern=${item#*|}
    if [[ "$label" == gw-a* ]]; then state=$a_config; else state=$b_config; fi
    assert_match "$label is exact" "$state" "^${pattern}$"
done

assert_ping_vyos "gw-a reaches its near public next hop" gw-a 203.0.113.2
assert_ping_vyos "gw-b reaches its near public next hop" gw-b 203.0.113.5
assert_ping_vyos "gw-a reaches the remote public endpoint" gw-a 203.0.113.6
assert_ping_vyos "gw-b reaches the remote public endpoint" gw-b 203.0.113.1
assert_ping_linux "host-a reaches host-b through IPsec" host-a 192.168.2.10
assert_ping_linux "host-b reaches host-a through IPsec" host-b 192.168.1.10

a_ike=$(vyos_op gw-a 'show vpn ike sa')
b_ike=$(vyos_op gw-b 'show vpn ike sa')
a_child=$(vyos_op gw-a 'show vpn ipsec sa')
b_child=$(vyos_op gw-b 'show vpn ipsec sa')
a_connections=$(vyos_op gw-a 'show vpn ipsec connections')
b_connections=$(vyos_op gw-b 'show vpn ipsec connections')
a_policy=$(vyos_op gw-a 'show vpn ipsec policy')
b_policy=$(vyos_op gw-b 'show vpn ipsec policy')

assert_count "gw-a has exactly one established IKE SA" "$a_ike" \
    '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' '1'
assert_count "gw-b has exactly one established IKE SA" "$b_ike" \
    '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' '1'
for item in \
    'gw-a IKE version|IKEv2' \
    'gw-a IKE encryption|AES_CBC_256' \
    'gw-a IKE integrity|HMAC_SHA2_256_128' \
    'gw-a IKE DH group|MODP_2048' \
    'gw-a NAT-T state|^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]+AES_CBC_256[[:space:]]+HMAC_SHA2_256_128[[:space:]]+MODP_2048[[:space:]]+no[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]*$' \
    'gw-b IKE version|IKEv2' \
    'gw-b IKE encryption|AES_CBC_256' \
    'gw-b IKE integrity|HMAC_SHA2_256_128' \
    'gw-b IKE DH group|MODP_2048' \
    'gw-b NAT-T state|^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]+AES_CBC_256[[:space:]]+HMAC_SHA2_256_128[[:space:]]+MODP_2048[[:space:]]+no[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]*$'; do
    label=${item%%|*}; pattern=${item#*|}
    if [[ "$label" == gw-a* ]]; then state=$a_ike; else state=$b_ike; fi
    assert_match "$label is exact" "$state" "$pattern"
done

assert_count "gw-a has exactly one up child SA" "$a_child" \
    '^GW-B-tunnel-1[[:space:]]+up[[:space:]]' '1'
assert_count "gw-b has exactly one up child SA" "$b_child" \
    '^GW-A-tunnel-1[[:space:]]+up[[:space:]]' '1'
assert_match "gw-a child uses exact ESP algorithms" "$a_child" \
    'AES_CBC_256/HMAC_SHA2_256_128'
assert_match "gw-b child uses exact ESP algorithms" "$b_child" \
    'AES_CBC_256/HMAC_SHA2_256_128'
assert_match "gw-a connection exposes the exact child" "$a_connections" \
    'GW-B-tunnel-1'
assert_match "gw-b connection exposes the exact child" "$b_connections" \
    'GW-A-tunnel-1'
assert_match "gw-a policy exposes its local selector" "$a_policy" '192\.168\.1\.0/24'
assert_match "gw-a policy exposes its remote selector" "$a_policy" '192\.168\.2\.0/24'
assert_match "gw-b policy exposes its local selector" "$b_policy" '192\.168\.2\.0/24'
assert_match "gw-b policy exposes its remote selector" "$b_policy" '192\.168\.1\.0/24'

a_xfrm_state=$(safe_node gw-a 'ip -s xfrm state')
b_xfrm_state=$(safe_node gw-b 'ip -s xfrm state')
a_xfrm_policy=$(safe_node gw-a 'ip -s xfrm policy')
b_xfrm_policy=$(safe_node gw-b 'ip -s xfrm policy')
assert_count "gw-a has exactly two directional ESP states" "$a_xfrm_state" \
    '^src 203\.0\.113\.(1|6) dst 203\.0\.113\.(1|6)$' '2'
assert_count "gw-b has exactly two directional ESP states" "$b_xfrm_state" \
    '^src 203\.0\.113\.(1|6) dst 203\.0\.113\.(1|6)$' '2'
assert_match "gw-a XFRM policy owns the exact selector pair" "$a_xfrm_policy" \
    'src 192\.168\.1\.0/24 dst 192\.168\.2\.0/24'
assert_match "gw-b XFRM policy owns the exact selector pair" "$b_xfrm_policy" \
    'src 192\.168\.2\.0/24 dst 192\.168\.1\.0/24'
assert_count "gw-a installs exactly three directional XFRM policies" "$a_xfrm_policy" \
    '^src 192\.168\.[12]\.0/24 dst 192\.168\.[12]\.0/24' '3'
assert_count "gw-b installs exactly three directional XFRM policies" "$b_xfrm_policy" \
    '^src 192\.168\.[12]\.0/24 dst 192\.168\.[12]\.0/24' '3'

a_positive_counters=$(grep -Ec '[1-9][0-9]*\(bytes\), [1-9][0-9]*\(packets\)' \
    <<<"$a_xfrm_state" || true)
b_positive_counters=$(grep -Ec '[1-9][0-9]*\(bytes\), [1-9][0-9]*\(packets\)' \
    <<<"$b_xfrm_state" || true)
if (( a_positive_counters >= 2 )); then
    pass "gw-a has positive inbound and outbound XFRM counters"
else
    fail "gw-a has positive inbound and outbound XFRM counters" "both directions did not record protected traffic"
fi
if (( b_positive_counters >= 2 )); then
    pass "gw-b has positive inbound and outbound XFRM counters"
else
    fail "gw-b has positive inbound and outbound XFRM counters" "both directions did not record protected traffic"
fi

summary
