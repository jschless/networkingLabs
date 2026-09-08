#!/usr/bin/env bash
# Grade the exact healthy Linux strongSwan IKEv2/VTI state without mutation.
set -u

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck disable=SC1091  # Repository helper path is resolved at runtime.
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init flexvpn-basics

container() { printf 'clab-%s-%s\n' "$TOPO_NAME" "$1"; }
safe_node() { docker exec "$(container "$1")" bash -c "$2" 2>/dev/null; }
container_image() { docker inspect --format '{{.Config.Image}}' "$(container "$1")" 2>/dev/null; }
normalize_file() { sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | sed '/^#/d; /^$/d'; }

assert_equal() {
    local label=$1 value=$2 expected=$3
    if [[ "$value" == "$expected" ]]; then pass "$label"; else fail "$label" "observed state differs from the exact lab contract"; fi
}
assert_match() {
    local label=$1 value=$2 pattern=$3
    if grep -qE -- "$pattern" <<<"$value"; then pass "$label"; else fail "$label" "required invariant is absent"; fi
}
assert_not_match() {
    local label=$1 value=$2 pattern=$3
    if ! grep -qE -- "$pattern" <<<"$value"; then pass "$label"; else fail "$label" "unexpected state remains active"; fi
}
assert_count() {
    local label=$1 value=$2 pattern=$3 expected=$4 count
    count=$(grep -Ec -- "$pattern" <<<"$value" || true)
    assert_equal "$label" "$count" "$expected"
}
assert_command() {
    local label=$1 node_name=$2 command=$3
    if safe_node "$node_name" "$command" >/dev/null; then pass "$label"; else fail "$label" "required node-local invariant is absent"; fi
}
assert_ping() {
    local label=$1 node_name=$2 destination=$3
    if safe_node "$node_name" "ping -c 2 -W 1 $destination" >/dev/null; then pass "$label"; else fail "$label" "the required path is not forwarding"; fi
}

actual_nodes=$(docker ps --format '{{.Names}}' | sed -n "s/^clab-${TOPO_NAME}-//p" | LC_ALL=C sort)
assert_equal "inventory contains exactly the seven intended nodes" "$actual_nodes" \
    $'gw-a\ngw-b\ngw-c\nhost-a\nhost-b\nhost-c\ninternet'
for gateway in gw-a gw-b gw-c; do
    assert_equal "$gateway uses the target-owned strongSwan image" "$(container_image "$gateway")" flexvpn-lab:local
    version=$(safe_node "$gateway" 'ipsec --version')
    assert_match "$gateway exposes live strongSwan IKEv2" "$version" 'strongSwan U5\.9\.8'
    assert_equal "$gateway runs a Linux kernel" "$(safe_node "$gateway" 'uname -s')" Linux
    assert_match "$gateway disables automatic table-220 route ownership" \
        "$(safe_node "$gateway" 'cat /etc/strongswan.conf')" 'install_routes[[:space:]]*=[[:space:]]*no'
    assert_equal "$gateway has no automatic table-220 routes" "$(safe_node "$gateway" 'ip -4 route show table 220')" ''
    assert_equal "$gateway forwards routed traffic" "$(safe_node "$gateway" 'sysctl -n net.ipv4.ip_forward')" 1
done
for incidental in host-a host-b host-c internet; do
    assert_equal "$incidental uses the incidental operations image" "$(container_image "$incidental")" ops-lab:local
    assert_match "$incidental is an incidental Alpine role" "$(safe_node "$incidental" 'cat /etc/alpine-release')" '^[0-9]+\.[0-9]+'
done

for item in \
    'host-a|eth1|192\.168\.1\.10/24|192.168.1.1' \
    'host-b|eth1|192\.168\.2\.10/24|192.168.2.1' \
    'host-c|eth1|192\.168\.3\.10/24|192.168.3.1'; do
    IFS='|' read -r node_name iface address gateway <<<"$item"
    assert_match "$node_name has its exact LAN address" "$(safe_node "$node_name" "ip -4 -o address show dev $iface")" "${iface}.*inet ${address}"
    default_route=$(safe_node "$node_name" 'ip -4 route show default' | sed -E 's/[[:space:]]+$//')
    assert_equal "$node_name has its exact default path" "$default_route" "default via $gateway dev $iface"
done

for item in \
    'gw-a|eth1|192\.168\.1\.1/24' 'gw-a|eth2|203\.0\.113\.1/30' \
    'gw-b|eth1|203\.0\.113\.6/30' 'gw-b|eth2|192\.168\.2\.1/24' \
    'gw-c|eth1|203\.0\.113\.10/30' 'gw-c|eth2|192\.168\.3\.1/24' \
    'internet|eth1|203\.0\.113\.2/30' 'internet|eth2|203\.0\.113\.5/30' \
    'internet|eth3|203\.0\.113\.9/30'; do
    IFS='|' read -r node_name iface address <<<"$item"
    assert_match "$node_name $iface address is exact" "$(safe_node "$node_name" "ip -4 -o address show dev $iface")" "${iface}.*inet ${address}"
done

declare -A expected_vti=( [gw-a]=2 [gw-b]=1 [gw-c]=1 )
declare -A expected_private_routes=( [gw-a]=3 [gw-b]=3 [gw-c]=3 )
for gateway in gw-a gw-b gw-c; do
    tunnel_state=$(safe_node "$gateway" 'ip -d tunnel show')
    address_state=$(safe_node "$gateway" "ip -4 -o address show | grep -E ' vti[0-9]+ ' || true")
    route_state=$(safe_node "$gateway" 'ip -4 route show table main')
    assert_count "$gateway has only the intended VTI inventory" "$tunnel_state" '^vti[0-9]+:' "${expected_vti[$gateway]}"
    assert_count "$gateway has only the intended VTI address inventory" "$address_state" 'inet 10\.10\.[12]\.[12]/30' "${expected_vti[$gateway]}"
    assert_count "$gateway has exactly three owned private LAN routes" "$route_state" '^192\.168\.[0-9]+\.0/24' "${expected_private_routes[$gateway]}"
done

a_tunnels=$(safe_node gw-a 'ip -d tunnel show')
b_tunnels=$(safe_node gw-b 'ip -d tunnel show')
c_tunnels=$(safe_node gw-c 'ip -d tunnel show')
assert_match "hub vti1 binds spoke1 endpoints to key 1" "$a_tunnels" '^vti1: ip/ip remote 203\.0\.113\.6 local 203\.0\.113\.1 .* key 1$'
assert_match "hub vti2 binds spoke2 endpoints to key 2" "$a_tunnels" '^vti2: ip/ip remote 203\.0\.113\.10 local 203\.0\.113\.1 .* key 2$'
assert_match "spoke1 vti0 uses deterministic key 1" "$b_tunnels" '^vti0: ip/ip remote 203\.0\.113\.1 local 203\.0\.113\.6 .* key 1$'
assert_match "spoke2 vti0 uses deterministic key 2" "$c_tunnels" '^vti0: ip/ip remote 203\.0\.113\.1 local 203\.0\.113\.10 .* key 2$'
for item in 'gw-a|vti1|10\.10\.1\.1/30' 'gw-a|vti2|10\.10\.2\.1/30' 'gw-b|vti0|10\.10\.1\.2/30' 'gw-c|vti0|10\.10\.2\.2/30'; do
    IFS='|' read -r node_name iface address <<<"$item"
    assert_match "$node_name $iface has its exact tunnel address" "$(safe_node "$node_name" "ip -4 -o address show dev $iface")" "inet ${address}"
    assert_equal "$node_name $iface disables duplicate policy lookup" "$(safe_node "$node_name" "sysctl -n net.ipv4.conf.$iface.disable_policy")" 1
    assert_equal "$node_name $iface disables strict reverse-path rejection" "$(safe_node "$node_name" "sysctl -n net.ipv4.conf.$iface.rp_filter")" 0
done

for item in \
    'gw-a|192.168.2.0/24|192.168.2.0/24 via 10.10.1.2 dev vti1' \
    'gw-a|192.168.3.0/24|192.168.3.0/24 via 10.10.2.2 dev vti2' \
    'gw-b|192.168.1.0/24|192.168.1.0/24 via 10.10.1.1 dev vti0' \
    'gw-b|192.168.3.0/24|192.168.3.0/24 via 10.10.1.1 dev vti0' \
    'gw-c|192.168.1.0/24|192.168.1.0/24 via 10.10.2.1 dev vti0' \
    'gw-c|192.168.2.0/24|192.168.2.0/24 via 10.10.2.1 dev vti0'; do
    IFS='|' read -r node_name prefix expected <<<"$item"
    observed_route=$(safe_node "$node_name" "ip -4 route show exact $prefix" | sed -E 's/[[:space:]]+$//')
    assert_equal "$node_name owns the exact protected route to $prefix" "$observed_route" "$expected"
done

expected_hub=$(normalize_file <"$(dirname "$0")/configs/gw-a/ipsec.conf")
assert_equal "hub IKEv2 definitions match the exact passive baseline" "$(safe_node gw-a 'cat /etc/ipsec.conf' | normalize_file)" "$expected_hub"
expected_b=$(normalize_file <<'EOF'
config setup
 uniqueids=yes
conn to-hub
 keyexchange=ikev2
 authby=secret
 type=tunnel
 ike=aes256-sha256-modp2048!
 esp=aes256gcm16-modp2048!
 dpdaction=restart
 dpddelay=30s
 left=203.0.113.6
 leftid=@spoke1
 leftsubnet=0.0.0.0/0
 right=203.0.113.1
 rightid=@hub
 rightsubnet=0.0.0.0/0
 mark=1
 auto=start
EOF
)
expected_c=${expected_b/203.0.113.6/203.0.113.10}
expected_c=${expected_c/@spoke1/@spoke2}
expected_c=${expected_c/mark=1/mark=2}
assert_equal "spoke1 learned IKEv2 definition is exact and unpolluted" "$(safe_node gw-b 'cat /etc/ipsec.conf' | normalize_file)" "$expected_b"
assert_equal "spoke2 learned IKEv2 definition is exact and unpolluted" "$(safe_node gw-c 'cat /etc/ipsec.conf' | normalize_file)" "$expected_c"
declare -A expected_secret_sha256=(
    [gw-a]=40f18fee73fc0aeb7f8143898e4e92efa5b5bfc00e58d0b197d2ad25798feddb
    [gw-b]=2eca00b1cc45862f1e3b6887fd949acb59bd6b8916a9aba27be6a0e5e0d800b8
    [gw-c]=f8ec4dd800fec7f96a50c18ddb06f5a9a35f385986e236de226c98750f8f33c8
)
for item in 'gw-a|2|@hub @(spoke1|spoke2)' 'gw-b|1|@spoke1 @hub' 'gw-c|1|@spoke2 @hub'; do
    IFS='|' read -r node_name lines identities <<<"$item"
    secret_meta=$(safe_node "$node_name" 'stat -c "%a %U %G" /etc/ipsec.secrets')
    secret_hash=$(safe_node "$node_name" 'sha256sum /etc/ipsec.secrets')
    secret_hash=${secret_hash%% *}
    secret_state=$(safe_node "$node_name" 'sed -E "s/: PSK .*/: PSK REDACTED/" /etc/ipsec.secrets')
    assert_equal "$node_name protects its credential file" "$secret_meta" '600 root root'
    assert_equal "$node_name credential contents match the exact saved secret" "$secret_hash" "${expected_secret_sha256[$node_name]}"
    assert_count "$node_name has only the intended credential entries" "$secret_state" 'PSK REDACTED' "$lines"
    assert_match "$node_name credential identities are exact" "$secret_state" "$identities"
done

a_status=$(safe_node gw-a 'ipsec status')
b_status=$(safe_node gw-b 'ipsec status')
c_status=$(safe_node gw-c 'ipsec status')
a_statusall=$(safe_node gw-a 'ipsec statusall')
b_statusall=$(safe_node gw-b 'ipsec statusall')
c_statusall=$(safe_node gw-c 'ipsec statusall')
assert_count "hub has exactly two established IKE SAs" "$a_status" 'ESTABLISHED' 2
assert_count "hub has exactly two installed CHILD SAs" "$a_status" 'INSTALLED, TUNNEL' 2
assert_count "spoke1 has exactly one established IKE SA" "$b_status" 'ESTABLISHED' 1
assert_count "spoke1 has exactly one installed CHILD SA" "$b_status" 'INSTALLED, TUNNEL' 1
assert_count "spoke2 has exactly one established IKE SA" "$c_status" 'ESTABLISHED' 1
assert_count "spoke2 has exactly one installed CHILD SA" "$c_status" 'INSTALLED, TUNNEL' 1
assert_match "hub terminates the exact spoke1 identity pair" "$a_status" '203\.0\.113\.1\[hub\].*203\.0\.113\.6\[spoke1\]'
assert_match "hub terminates the exact spoke2 identity pair" "$a_status" '203\.0\.113\.1\[hub\].*203\.0\.113\.10\[spoke2\]'
for item in "gw-a|$a_statusall" "gw-b|$b_statusall" "gw-c|$c_statusall"; do
    node_name=${item%%|*}; state=${item#*|}
    assert_match "$node_name negotiates exact IKE algorithms" "$state" 'AES_CBC_256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048'
    assert_match "$node_name negotiates exact ESP encryption/integrity" "$state" 'AES_GCM_16_256'
done

a_state=$(safe_node gw-a 'ip -s xfrm state')
b_state=$(safe_node gw-b 'ip -s xfrm state')
c_state=$(safe_node gw-c 'ip -s xfrm state')
a_policy=$(safe_node gw-a 'ip -s xfrm policy')
b_policy=$(safe_node gw-b 'ip -s xfrm policy')
c_policy=$(safe_node gw-c 'ip -s xfrm policy')
assert_count "hub has exactly four total XFRM states" "$a_state" '^src ' 4
assert_count "spoke1 has exactly two total XFRM states" "$b_state" '^src ' 2
assert_count "spoke2 has exactly two total XFRM states" "$c_state" '^src ' 2
assert_count "hub has exactly four directional ESP states" "$a_state" '^src 203\.0\.113\.' 4
assert_count "spoke1 has exactly two directional ESP states" "$b_state" '^src 203\.0\.113\.' 2
assert_count "spoke2 has exactly two directional ESP states" "$c_state" '^src 203\.0\.113\.' 2
assert_count "hub outbound states contain exactly one mark 1" "$a_state" '^[[:space:]]*mark 0x1/0xffffffff' 1
assert_count "hub outbound states contain exactly one mark 2" "$a_state" '^[[:space:]]*mark 0x2/0xffffffff' 1
assert_count "spoke1 outbound state is deterministically marked 1" "$b_state" '^[[:space:]]*mark 0x1/0xffffffff' 1
assert_count "spoke2 outbound state is deterministically marked 2" "$c_state" '^[[:space:]]*mark 0x2/0xffffffff' 1
assert_count "hub has exactly six total marked XFRM policies" "$a_policy" '^[[:space:]]*mark 0x' 6
assert_count "spoke1 has exactly three total marked XFRM policies" "$b_policy" '^[[:space:]]*mark 0x' 3
assert_count "spoke2 has exactly three total marked XFRM policies" "$c_policy" '^[[:space:]]*mark 0x' 3
assert_count "hub has exactly six learned tunnel-policy templates" "$a_policy" 'mode tunnel' 6
assert_count "spoke1 has exactly three learned tunnel-policy templates" "$b_policy" 'mode tunnel' 3
assert_count "spoke2 has exactly three learned tunnel-policy templates" "$c_policy" 'mode tunnel' 3
assert_count "hub policies bind three directions to mark 1" "$a_policy" '^[[:space:]]*mark 0x1/0xffffffff' 3
assert_count "hub policies bind three directions to mark 2" "$a_policy" '^[[:space:]]*mark 0x2/0xffffffff' 3
assert_count "spoke1 policies bind three directions to mark 1" "$b_policy" '^[[:space:]]*mark 0x1/0xffffffff' 3
assert_count "spoke2 policies bind three directions to mark 2" "$c_policy" '^[[:space:]]*mark 0x2/0xffffffff' 3

assert_equal "transit IPv4 forwarding is enabled" "$(safe_node internet 'sysctl -n net.ipv4.ip_forward')" 1
for rule in \
    'FLEXVPN_PUBLIC_ESTABLISHED|-m conntrack --ctstate RELATED,ESTABLISHED' \
    'FLEXVPN_PUBLIC_IKE|-p udp' 'FLEXVPN_PUBLIC_ESP|-p esp' \
    'FLEXVPN_BLOCK_PRIVATE_SOURCE|-s 192.168.0.0/16' \
    'FLEXVPN_BLOCK_PRIVATE_DESTINATION|-d 192.168.0.0/16' \
    'FLEXVPN_PUBLIC_UNDERLAY|-s 203.0.113.0/24'; do
    label=${rule%%|*}; pattern=${rule#*|}
    assert_match "transit owns $label" "$(safe_node internet 'iptables -S FORWARD')" "$pattern.*$label"
done
assert_equal "transit default FORWARD policy is DROP" "$(safe_node internet "iptables -S FORWARD | sed -n 's/^-P FORWARD //p'")" DROP
assert_count "transit has exactly six ordered containment rules" "$(safe_node internet 'iptables -S FORWARD')" '^-A FORWARD ' 6

assert_ping "gw-a reaches spoke1 on the public underlay" gw-a 203.0.113.6
assert_ping "gw-a reaches spoke2 on the public underlay" gw-a 203.0.113.10
assert_ping "host-a reaches host-b through marked IPsec" host-a 192.168.2.10
assert_ping "host-b reaches host-a through marked IPsec" host-b 192.168.1.10
assert_ping "host-a reaches host-c through marked IPsec" host-a 192.168.3.10
assert_ping "host-c reaches host-a through marked IPsec" host-c 192.168.1.10

a_state=$(safe_node gw-a 'ip -s xfrm state')
b_state=$(safe_node gw-b 'ip -s xfrm state')
c_state=$(safe_node gw-c 'ip -s xfrm state')
for state in "$a_state" "$b_state" "$c_state"; do
    assert_match "protected ESP state records live packet counters" "$state" '[1-9][0-9]*\(bytes\), [1-9][0-9]*\(packets\)'
done

b_to_hub_before=$(safe_node gw-a 'cat /sys/class/net/vti1/statistics/rx_packets')
hub_to_c_before=$(safe_node gw-a 'cat /sys/class/net/vti2/statistics/tx_packets')
assert_ping "host-b reaches host-c through the hub hairpin" host-b 192.168.3.10
b_to_hub_after=$(safe_node gw-a 'cat /sys/class/net/vti1/statistics/rx_packets')
hub_to_c_after=$(safe_node gw-a 'cat /sys/class/net/vti2/statistics/tx_packets')
if [[ "$b_to_hub_before" =~ ^[0-9]+$ && "$hub_to_c_before" =~ ^[0-9]+$ \
    && "$b_to_hub_after" -gt "$b_to_hub_before" && "$hub_to_c_after" -gt "$hub_to_c_before" ]]; then
    pass "hub hairpin increments spoke1 ingress and spoke2 egress VTI counters"
else
    fail "hub hairpin increments spoke1 ingress and spoke2 egress VTI counters" "traffic did not traverse both hub VTIs"
fi
assert_ping "host-c reaches host-b through the reverse hub hairpin" host-c 192.168.2.10

summary
