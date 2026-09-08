#!/usr/bin/env bash
# Grade the exact healthy native VyOS certificate-protected Phase 3 capstone.
set -u

usage() {
    cat <<'EOF'
Usage: labs/dmvpn-phase3-ipsec-capstone/check.sh

Grade the complete healthy deployment without changing live or saved
configuration. The checker resets only ephemeral NHRP cache/shortcut state to
prove the summary-first transition, sends bounded traffic, and keeps all PKI
failure messages generic so private material is never printed.
EOF
}
case ${1:-} in -h|--help) usage; exit 0 ;; '') ;; *) usage >&2; exit 2 ;; esac
(( $# == 0 )) || { usage >&2; exit 2; }

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init dmvpn-phase3-ipsec-capstone

container() { printf 'clab-%s-%s\n' "$TOPO_NAME" "$1"; }
safe_node() { docker exec "$(container "$1")" sh -c "$2" 2>/dev/null; }
container_image() { docker inspect --format '{{.Config.Image}}' "$(container "$1")" 2>/dev/null; }
normalize() {
    sed -E "s/'//g; s/\"//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//" | \
        sed '/^[[:space:]]*$/d' | LC_ALL=C sort
}
selected() { grep -E "$1" | normalize; }
interface_v4() { safe_node "$1" "ip -4 -o address show dev $2" | awk '{print $4}' | LC_ALL=C sort; }
management_interface_commands() {
    local router=$1 container_name bridge_label network_ref network_id metadata
    local v4_prefix v6_prefix
    local -a addresses
    container_name=$(container "$router")
    bridge_label=$(docker inspect --format \
        '{{index .Config.Labels "clab-mgmt-net-bridge"}}' "$container_name" 2>/dev/null) || return 1
    [[ "$bridge_label" =~ ^br-([[:xdigit:]]{12})$ ]] || return 1
    network_ref=${BASH_REMATCH[1]}
    network_id=$(docker network inspect --format '{{.Id}}' "$network_ref" 2>/dev/null) || return 1
    [[ "$network_id" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    metadata=$(docker inspect --format \
        '{{range .NetworkSettings.Networks}}{{.NetworkID}}|{{.IPAddress}}|{{.IPPrefixLen}}|{{.GlobalIPv6Address}}|{{.GlobalIPv6PrefixLen}}{{println}}{{end}}' \
        "$container_name" 2>/dev/null | awk -F'|' -v network_id="$network_id" '
            $1 == network_id {
                matches++
                print $2 "/" $3
                print $4 "/" $5
            }
            END { if (matches != 1) exit 1 }
        ') || return 1
    mapfile -t addresses <<<"$metadata"
    [[ ${#addresses[@]} == 2 ]] || return 1
    [[ ${addresses[0]} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || return 1
    [[ ${addresses[1]} =~ ^[[:xdigit:]:]+/[0-9]{1,3}$ ]] || return 1
    v4_prefix=${addresses[0]##*/}
    v6_prefix=${addresses[1]##*/}
    (( 10#$v4_prefix <= 32 && 10#$v6_prefix <= 128 )) || return 1
    printf 'set interfaces ethernet eth0 address %s\n' "${addresses[0]}" "${addresses[1]}"
}

assert_equal() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then pass "$label"; else fail "$label" 'observed state differs from the capstone contract'; fi
}
assert_match() {
    local label=$1 actual=$2 pattern=$3
    if grep -qE "$pattern" <<<"$actual"; then pass "$label"; else fail "$label" 'required correlated state is absent'; fi
}
assert_not_match() {
    local label=$1 actual=$2 pattern=$3
    if ! grep -qE "$pattern" <<<"$actual"; then pass "$label"; else fail "$label" 'unexpected or forbidden state remains'; fi
}
assert_count() {
    local label=$1 actual=$2 pattern=$3 expected=$4 count
    count=$(grep -Ec "$pattern" <<<"$actual" || true)
    assert_equal "$label" "$count" "$expected"
}
assert_source_ping() {
    local label=$1 node=$2 source=$3 destination=$4
    if timeout 6 docker exec "$(container "$node")" ping -I "$source" -c 2 -W 1 \
        "$destination" >/dev/null 2>&1; then pass "$label"; else fail "$label" 'bounded source-specific traffic failed'; fi
}
shortcut_rows() {
    awk '
        {
            row=$0
            sub(/^[[:space:]]+/,"",row)
            sub(/[[:space:]]+$/,"",row)
            gsub(/[[:space:]]+/," ",row)
        }
        row=="" { next }
        tolower(row) ~ /^(type|prefix)([[:space:]]+(type|prefix|state|via|identity|nbma|interface))+$/ { next }
        row ~ /^[-=]+([[:space:]]+[-=]+)*$/ { next }
        tolower(row) ~ /^%?[[:space:]]*no[[:space:]]+/ { next }
        { print row }
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
flatten_xfrm() {
    awk '
        function clean(line) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); gsub(/[[:space:]]+/, " ", line); return line }
        function emit() { if (block != "") print block }
        /^src[[:space:]]/ { emit(); block=clean($0); next }
        block != "" && NF { block=block " | " clean($0) }
        END { emit() }
    '
}
xfrm_policy_facts() {
    awk -F ' \\| ' '
        {
            header=$1
            detail=$2
            if (header ~ /^src [^ ]+ dst [^ ]+ proto gre uid 0$/) {
                split(header, fields, " ")
                print "gre " fields[2] " " fields[4] " " fields[6]
                next
            }
            family=""
            if (header == "src 0.0.0.0/0 dst 0.0.0.0/0 uid 0") family="ipv4"
            if (header == "src ::/0 dst ::/0 uid 0") family="ipv6"
            if (family == "") next
            if (detail !~ /^socket (in|out) action allow index [0-9]+ priority 0 share any flag \(0x00000000\)$/) next
            has_template=0
            for (part=3; part<=NF; part++) {
                if ($part ~ /^tmpl /) has_template=1
            }
            if (!has_template) {
                split(detail, fields, " ")
                print "socket " family " " fields[2]
            }
        }
    '
}
extract_value() {
    local prefix=$1
    awk -v prefix="$prefix" '
        index($0,prefix)==1 {
            value=substr($0,length(prefix)+1)
            sub(/^[[:space:]]+/,"",value)
            sub(/^\047/,"",value); sub(/\047$/,"",value)
            sub(/^\042/,"",value); sub(/\042$/,"",value)
            print value
        }
    '
}
pem_stream() {
    local kind=$1 body=$2
    printf '%s\n' "-----BEGIN $kind-----"
    fold -w 64 <<<"$body"
    printf '%s\n' "-----END $kind-----"
}
cert_fingerprint() { pem_stream CERTIFICATE "$1" | openssl x509 -noout -fingerprint -sha256 2>/dev/null; }
cert_pub_hash() { pem_stream CERTIFICATE "$1" | openssl x509 -pubkey -noout 2>/dev/null | openssl sha256; }
key_pub_hash() { pem_stream 'PRIVATE KEY' "$1" | openssl pkey -pubout 2>/dev/null | openssl sha256; }
xfrm_packets() {
    local node=$1 source=$2 destination=$3 block
    block=$(safe_node "$node" 'ip -s xfrm state' | awk -v source="$source" -v destination="$destination" '
        /^src / {
            hit=($2==source && $4==destination)
            current=0
        }
        hit && /^[[:space:]]*lifetime current:[[:space:]]*$/ {
            current=1
            next
        }
        hit && current && /^[[:space:]]*[0-9]+\(bytes\),[[:space:]]*[0-9]+\(packets\)[[:space:]]*$/ {
            print
            exit
        }
    ')
    sed -nE 's/^[[:space:]]*[0-9]+\(bytes\),[[:space:]]*([0-9]+)\(packets\)[[:space:]]*$/\1/p' <<<"$block"
}

declare -A wan=( [hub]=10.0.0.1 [spoke1]=10.0.0.11 [spoke2]=10.0.0.12 [spoke3]=10.0.0.13 )
declare -A overlay=( [hub]=172.16.0.1 [spoke1]=172.16.0.11 [spoke2]=172.16.0.12 [spoke3]=172.16.0.13 )
declare -A rank=( [hub]=0 [spoke1]=1 [spoke2]=2 [spoke3]=3 )
routers=(hub spoke1 spoke2 spoke3)

actual_nodes=$(docker ps --format '{{.Names}}' | sed -n "s/^clab-${TOPO_NAME}-//p" | LC_ALL=C sort)
assert_equal 'inventory contains exactly the six intended nodes' "$actual_nodes" $'br-wan\nca\nhub\nspoke1\nspoke2\nspoke3'
for router in "${routers[@]}"; do
    assert_equal "$router uses native VyOS" "$(container_image "$router")" vyos:local
    assert_match "$router is a live VyOS learned role" "$(vyos_op "$router" 'show version')" 'VyOS'
done
assert_equal 'incidental WAN bridge uses ops-lab:local' "$(container_image br-wan)" ops-lab:local
assert_equal 'intrinsic CA uses the purpose-built image' "$(container_image ca)" dmvpn-pki:local
assert_match 'CA image is Alpine 3.20' "$(safe_node ca 'cat /etc/alpine-release')" '^3\.20\.'
assert_match 'CA image has the pinned OpenSSL package version' "$(safe_node ca 'apk list --installed openssl 2>/dev/null')" '^openssl-3\.3\.7-r0[[:space:]]'

bridge_links=$(safe_node br-wan 'bridge link show master br0')
bridge_ports=$(awk '{ port=$2; sub(/:.*/,"",port); sub(/@.*/,"",port); print port }' <<<"$bridge_links" | LC_ALL=C sort)
assert_equal 'WAN bridge has exactly four intended members' "$bridge_ports" $'eth1\neth2\neth3\neth4'
assert_count 'all WAN bridge members are forwarding' "$bridge_links" 'master br0 state forwarding' 4
assert_match 'WAN bridge is up' "$(safe_node br-wan 'ip -o link show dev br0')" 'UP'

for router in "${routers[@]}"; do
    assert_equal "$router WAN has exactly its intended /24" "$(interface_v4 "$router" eth1)" "${wan[$router]}/24"
    assert_equal "$router overlay has exactly its intended /32" "$(interface_v4 "$router" tun0)" "${overlay[$router]}/32"
    assert_equal "$router tun0 MTU is exactly 1400" "$(safe_node "$router" 'cat /sys/class/net/tun0/mtu')" 1400
    assert_match "$router tun0 is mGRE without a fixed remote" "$(safe_node "$router" 'ip -d link show dev tun0')" 'gre remote any local any dev eth1'
done
for number in 1 2 3; do
    assert_equal "spoke$number service interface is exact" "$(interface_v4 "spoke$number" dum0)" "192.168.${number}.1/24"
done

hub_expected_protocols=$(cat <<'EOF' | normalize
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
all_config=
spoke_config=
declare -A live_config saved_config
for router in "${routers[@]}"; do
    live_config[$router]=$(vyos_op "$router" 'show configuration commands')
    saved_config[$router]=$(safe_node "$router" '/usr/bin/vyos-config-to-commands /config/config.boot')
    all_config+=$'\n'"${live_config[$router]}"
    [[ "$router" == hub ]] || spoke_config+=$'\n'"${live_config[$router]}"

    management=$(management_interface_commands "$router" 2>/dev/null || \
        printf '%s\n' 'set interfaces __invalid_containerlab_management_metadata__')
    expected_interfaces=$(cat <<EOF | normalize
${management}
set interfaces ethernet eth1 address ${wan[$router]}/24
set interfaces ethernet eth1 description WAN NBMA
set interfaces ethernet eth1 offload gso
set interfaces ethernet eth1 offload sg
set interfaces loopback lo
set interfaces tunnel tun0 address ${overlay[$router]}/32
set interfaces tunnel tun0 description mGRE encrypted Phase 3 $router
set interfaces tunnel tun0 enable-multicast
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 mtu 1400
set interfaces tunnel tun0 source-interface eth1
EOF
)
    if [[ "$router" != hub ]]; then
        number=${router#spoke}
        expected_interfaces+=$'\n'"$(cat <<EOF | normalize
set interfaces dummy dum0 address 192.168.${number}.1/24
set interfaces dummy dum0 description Service LAN ${number}
EOF
)"
        expected_interfaces=$(normalize <<<"$expected_interfaces")
    fi
    for state_kind in live saved; do
        [[ "$state_kind" == live ]] && state=${live_config[$router]} || state=${saved_config[$router]}
        assert_equal "$router complete configured interface inventory is exact in $state_kind state" \
            "$(selected '^set interfaces ' <<<"$state")" "$expected_interfaces"
    done

    if [[ "$router" == hub ]]; then
        expected_protocols=$hub_expected_protocols
    else
        expected_protocols=$(cat <<EOF | normalize
set protocols nhrp tunnel tun0 holdtime 300
set protocols nhrp tunnel tun0 map tunnel-ip 172.16.0.1 nbma 10.0.0.1
set protocols nhrp tunnel tun0 multicast 10.0.0.1
set protocols nhrp tunnel tun0 network-id 1
set protocols nhrp tunnel tun0 nhs tunnel-ip 172.16.0.1 nbma 10.0.0.1
set protocols nhrp tunnel tun0 registration-no-unique
set protocols nhrp tunnel tun0 shortcut
set protocols ospf area 0 network ${overlay[$router]}/32
set protocols ospf interface tun0 network point-to-multipoint
set protocols ospf parameters router-id ${wan[$router]}
EOF
)
    fi
    for state_kind in live saved; do
        [[ "$state_kind" == live ]] && state=${live_config[$router]} || state=${saved_config[$router]}
        assert_equal "$router learned protocols are exact in $state_kind state" \
            "$(selected '^set protocols (nhrp|ospf|static)([[:space:]]|$)' <<<"$state")" "$expected_protocols"
    done
done
assert_not_match 'no BGP or alternate routing bypass exists' "$all_config" '^set protocols (bgp|isis|rip)([[:space:]]|$)'
assert_not_match 'spokes never advertise service LANs in the shared OSPF area' "$spoke_config" '^set protocols ospf area .* network 192\.168\.'
assert_not_match 'spokes have no service static-route bypass' "$spoke_config" '^set protocols static route 192\.168\.'
assert_not_match 'no fixed tunnel remote simulates mGRE' "$all_config" '^set interfaces tunnel tun0 remote '

# The CA validates every private key and certificate internally. Only public
# fingerprints and derived public-key hashes cross into the grader.
if timeout 35 docker exec "$(container ca)" /opt/dmvpn-pki/validate-pki.sh --all >/dev/null 2>&1; then
    pass 'complete CA workspace passes exact secret-safe semantic validation'
else
    fail 'complete CA workspace passes exact secret-safe semantic validation' 'CA policy, inventory, or key/certificate state is invalid'
fi
for router in "${routers[@]}"; do
    if timeout 25 docker exec "$(container ca)" /opt/dmvpn-pki/validate-pki.sh "$router" >/dev/null 2>&1; then
        pass "$router source certificate passes identity, usage, chain, and key checks"
    else
        fail "$router source certificate passes identity, usage, chain, and key checks" 'router PKI semantics are invalid'
    fi
    pki_lines=$(selected '^set pki ' <<<"${live_config[$router]}")
    assert_count "$router has exactly three PKI import leaves" "$pki_lines" '^set pki ' 3
    assert_match "$router has exactly the named CA import" "$pki_lines" '^set pki ca DMVPN-CA certificate [A-Za-z0-9+/=]+$'
    assert_match "$router has exactly its named certificate import" "$pki_lines" "^set pki certificate ${router}-cert certificate [A-Za-z0-9+/=]+$"
    assert_match "$router has exactly its private-key import" "$pki_lines" "^set pki certificate ${router}-cert private key [A-Za-z0-9+/=]+$"
    saved_pki=$(selected '^set pki ' <<<"${saved_config[$router]}")
    assert_equal "$router live and saved PKI definitions are identical" "$pki_lines" "$saved_pki"

    ca_body=$(extract_value 'set pki ca DMVPN-CA certificate' <<<"${live_config[$router]}")
    cert_body=$(extract_value "set pki certificate ${router}-cert certificate" <<<"${live_config[$router]}")
    key_body=$(extract_value "set pki certificate ${router}-cert private key" <<<"${live_config[$router]}")
    source_ca_fp=$(safe_node ca "openssl x509 -in /lab/pki/ca/dmvpn-ca.pem -noout -fingerprint -sha256")
    source_cert_fp=$(safe_node ca "openssl x509 -in /lab/pki/certs/$router.pem -noout -fingerprint -sha256")
    assert_equal "$router imported CA matches the validated workspace" "$(cert_fingerprint "$ca_body")" "$source_ca_fp"
    assert_equal "$router imported leaf matches the validated workspace" "$(cert_fingerprint "$cert_body")" "$source_cert_fp"
    assert_equal "$router imported private key matches its leaf certificate" "$(key_pub_hash "$key_body")" "$(cert_pub_hash "$cert_body")"
    ca_body='' cert_body='' key_body=''
done

base_vpn=$(cat <<'EOF' | normalize
set vpn ipsec esp-group DMVPN-ESP lifetime 3600
set vpn ipsec esp-group DMVPN-ESP mode transport
set vpn ipsec esp-group DMVPN-ESP pfs dh-group14
set vpn ipsec esp-group DMVPN-ESP proposal 10 encryption aes256
set vpn ipsec esp-group DMVPN-ESP proposal 10 hash sha256
set vpn ipsec ike-group DMVPN-IKE dead-peer-detection action restart
set vpn ipsec ike-group DMVPN-IKE dead-peer-detection interval 30
set vpn ipsec ike-group DMVPN-IKE dead-peer-detection timeout 120
set vpn ipsec ike-group DMVPN-IKE key-exchange ikev2
set vpn ipsec ike-group DMVPN-IKE lifetime 3600
set vpn ipsec ike-group DMVPN-IKE proposal 10 dh-group 14
set vpn ipsec ike-group DMVPN-IKE proposal 10 encryption aes256
set vpn ipsec ike-group DMVPN-IKE proposal 10 hash sha256
EOF
)
for router in "${routers[@]}"; do
    expected_vpn=$base_vpn
    for remote in "${routers[@]}"; do
        [[ "$remote" == "$router" ]] && continue
        connection=none
        (( rank[$router] < rank[$remote] )) && connection=initiate
        expected_vpn+=$'\n'"$(cat <<EOF | normalize
set vpn ipsec site-to-site peer $remote authentication local-id $router.dmvpn.lab
set vpn ipsec site-to-site peer $remote authentication mode x509
set vpn ipsec site-to-site peer $remote authentication remote-id $remote.dmvpn.lab
set vpn ipsec site-to-site peer $remote authentication x509 ca-certificate DMVPN-CA
set vpn ipsec site-to-site peer $remote authentication x509 certificate $router-cert
set vpn ipsec site-to-site peer $remote connection-type $connection
set vpn ipsec site-to-site peer $remote default-esp-group DMVPN-ESP
set vpn ipsec site-to-site peer $remote ike-group DMVPN-IKE
set vpn ipsec site-to-site peer $remote local-address ${wan[$router]}
set vpn ipsec site-to-site peer $remote remote-address ${wan[$remote]}
set vpn ipsec site-to-site peer $remote tunnel 1 protocol gre
EOF
)"
    done
    expected_vpn=$(normalize <<<"$expected_vpn")
    live_vpn=$(selected '^set vpn ipsec ' <<<"${live_config[$router]}")
    saved_vpn=$(selected '^set vpn ipsec ' <<<"${saved_config[$router]}")
    assert_equal "$router live VPN definition is exact" "$live_vpn" "$expected_vpn"
    assert_equal "$router saved VPN definition is exact" "$saved_vpn" "$expected_vpn"
    assert_not_match "$router has no PSK material" "$live_vpn" '^set vpn ipsec authentication psk '
    assert_count "$router has exactly three static x509 peers" "$live_vpn" '^set vpn ipsec site-to-site peer [^ ]+ remote-address ' 3
    assert_count "$router has exactly the deterministic initiator count" "$live_vpn" '^set vpn ipsec site-to-site peer [^ ]+ connection-type initiate$' "$((3 - rank[$router]))"
done

# Exact control-plane state before any service traffic.
hub_nhrp=$(vyos_frr hub 'show ip nhrp')
assert_count 'hub NHRP has exactly four local/registered rows' "$hub_nhrp" '^tun0[[:space:]]' 4
hub_neighbors=$(vyos_frr hub 'show ip ospf neighbor')
assert_count 'hub has exactly three OSPF neighbors' "$hub_neighbors" '^[0-9]+\.' 3
for number in 1 2 3; do
    last=$((10 + number))
    assert_match "hub correlates spoke$number NHRP registration" "$hub_nhrp" "^tun0[[:space:]]+dynamic[[:space:]]+172\.16\.0\.${last}[[:space:]]+10\.0\.0\.${last}[[:space:]]+10\.0\.0\.${last}"
    assert_match "hub has spoke$number Full at its overlay" "$hub_neighbors" "^10\.0\.0\.${last}[[:space:]].*Full/[^[:space:]]+[[:space:]].*172\.16\.0\.${last}([[:space:]]|$)"
done

reset_ok=true
for source in 1 2 3; do
    timeout 10 docker exec "$(container "spoke$source")" vtysh \
        -c 'clear ip nhrp shortcut' -c 'clear ip nhrp cache' >/dev/null 2>&1 || reset_ok=false
done
if [[ "$reset_ok" == true ]]; then
    pass 'ephemeral shortcut state reset without configuration change'
else
    fail 'ephemeral shortcut state reset without configuration change' 'bounded operational reset failed'
fi
sleep 2
for number in 1 2 3; do
    spoke=spoke$number
    routes=$(vyos_frr "$spoke" 'show ip route ospf')
    shortcuts=$(shortcut_rows <<<"$(vyos_frr "$spoke" 'show ip nhrp shortcut')")
    neighbors=$(vyos_frr "$spoke" 'show ip ospf neighbor')
    assert_count "$spoke has exactly one OSPF neighbor" "$neighbors" '^[0-9]+\.' 1
    assert_match "$spoke has only the hub Full" "$neighbors" '^10\.0\.0\.1[[:space:]].*Full/[^[:space:]]+[[:space:]].*172\.16\.0\.1([[:space:]]|$)'
    assert_equal "$spoke pre-traffic shortcut table is empty" "$shortcuts" ''
    assert_count "$spoke has exactly one OSPF service summary" "$routes" '^O>\*[[:space:]]+192\.168\.0\.0/16' 1
    assert_match "$spoke summary initially resolves through the hub" "$routes" '^O>\*[[:space:]]+192\.168\.0\.0/16.*via 172\.16\.0\.1, tun0'
    lsa=$(vyos_frr "$spoke" 'show ip ospf database external')
    assert_equal "$spoke has one exact hub Type-2 /16 LSA" "$(external_lsa_facts <<<"$lsa")" $'advertiser 10.0.0.1\nid 192.168.0.0\nmask /16\nmetric-type 2\ntype AS-external-LSA'
    for other in 1 2 3; do
        [[ "$other" == "$number" ]] && continue
        last=$((10 + other))
        assert_not_match "$spoke has no remote OSPF service specific for spoke$other" "$routes" "^O.*192\.168\.${other}\.(0/24|1/32)"
        assert_match "$spoke learns spoke$other overlay through the hub" "$routes" "^O[^[:space:]]*[[:space:]]+172\.16\.0\.${last}/32.*via 172\.16\.0\.1, tun0"
        fib=$(safe_node "$spoke" "ip -4 route get 192.168.${other}.1 from 192.168.${number}.1")
        assert_match "$spoke initial service FIB for spoke$other uses the hub" "$fib" "^192\.168\.${other}\.1 from 192\.168\.${number}\.1 via 172\.16\.0\.1 dev tun0([[:space:]]|$)"
    done
done

if seed_output=$(timeout 90 "$REPO_ROOT/labs/dmvpn-phase3-ipsec-capstone/seed-shortcuts.sh" 2>&1); then
    pass 'all six current-image shortcut paths converge under bounded traffic'
else
    fail 'all six current-image shortcut paths converge under bounded traffic' "${seed_output//$'\n'/; }"
fi
for source in 1 2 3; do
    expected_shortcuts=
    for destination in 1 2 3; do
        [[ "$source" == "$destination" ]] && continue
        remote_last=$((10 + destination))
        expected_shortcuts+="dynamic 192.168.${destination}.0/24 172.16.0.${remote_last} spoke${destination}.dmvpn.lab"$'\n'
    done
    expected_shortcuts=$(sed '/^$/d' <<<"$expected_shortcuts" | LC_ALL=C sort)
    actual_shortcuts=$(shortcut_rows <<<"$(vyos_frr "spoke$source" 'show ip nhrp shortcut')" | LC_ALL=C sort)
    assert_equal "spoke$source has exactly two correlated prefix/via/x509-identity shortcut rows" \
        "$actual_shortcuts" "$expected_shortcuts"
done
for source in 1 2 3; do
    for destination in 1 2 3; do
        [[ "$source" == "$destination" ]] && continue
        assert_source_ping "spoke$source source-specific service reaches spoke$destination" \
            "spoke$source" "192.168.${source}.1" "192.168.${destination}.1"
    done
done

# Exact IKE, CHILD, connection selector, XFRM state, and policy ownership.
for router in "${routers[@]}"; do
    ike=$(vyos_op "$router" 'show vpn ike sa')
    child=$(vyos_op "$router" 'show vpn ipsec sa')
    connections=$(vyos_op "$router" 'show vpn ipsec connections')
    state=$(safe_node "$router" 'ip -s xfrm state')
    policy=$(safe_node "$router" 'ip -s xfrm policy')
    assert_count "$router has exactly three established IKEv2 SAs" "$ike" '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]' 3
    assert_count "$router IKE rows all use AES256/SHA256/DH14" "$ike" '^[[:space:]]*up[[:space:]]+IKEv2[[:space:]]+AES_CBC_256[[:space:]]+HMAC_SHA2_256_128[[:space:]]+MODP_2048[[:space:]]' 3
    assert_count "$router has exactly three up CHILD SAs" "$child" '^[^[:space:]]+[[:space:]]+up[[:space:]]' 3
    assert_count "$router CHILD records all use AES256/SHA256" "$child" 'AES_CBC_256/HMAC_SHA2_256_128' 3
    for remote in "${routers[@]}"; do
        [[ "$remote" == "$router" ]] && continue
        assert_count "$router has one up child for $remote" "$child" "^${remote}-tunnel-1[[:space:]]+up[[:space:]]" 1
        assert_match "$router connection exposes local GRE selector for $remote" "$connections" "${wan[$router]}/32\\[gre\\]"
        assert_match "$router connection exposes remote GRE selector for $remote" "$connections" "${wan[$remote]}/32\\[gre\\]"
    done
    state_headers=$(awk '/^src / { print $2 " " $4 }' <<<"$state" | LC_ALL=C sort)
    expected_state=
    for remote in "${routers[@]}"; do
        [[ "$remote" == "$router" ]] && continue
        expected_state+="${wan[$router]} ${wan[$remote]}"$'\n'"${wan[$remote]} ${wan[$router]}"$'\n'
    done
    expected_state=$(sed '/^$/d' <<<"$expected_state" | LC_ALL=C sort)
    assert_equal "$router has exactly six expected XFRM state directions" "$state_headers" "$expected_state"
    state_blocks=$(flatten_xfrm <<<"$state")
    assert_count "$router all six states are ESP transport mode" "$state_blocks" '(^| \| )proto esp .* mode transport([[:space:]]|$)' 6
    assert_count "$router has exactly fourteen total top-level XFRM policies" "$policy" '^src ' 14
    expected_policy_facts=
    for remote in "${routers[@]}"; do
        [[ "$remote" == "$router" ]] && continue
        expected_policy_facts+="gre ${wan[$router]}/32 ${wan[$remote]}/32 gre"$'\n'
        expected_policy_facts+="gre ${wan[$remote]}/32 ${wan[$router]}/32 gre"$'\n'
    done
    policy_blocks=$(flatten_xfrm <<<"$policy")
    expected_policy_facts+=$(cat <<'EOF'
socket ipv4 in
socket ipv4 in
socket ipv4 out
socket ipv4 out
socket ipv6 in
socket ipv6 in
socket ipv6 out
socket ipv6 out
EOF
)
    expected_policy_facts=$(sed '/^$/d' <<<"$expected_policy_facts" | LC_ALL=C sort)
    policy_facts=$(xfrm_policy_facts <<<"$policy_blocks" | LC_ALL=C sort)
    assert_equal "$router has only six GRE peers plus eight exact native socket bypass policies" \
        "$policy_facts" "$expected_policy_facts"
    assert_count "$router all six GRE policies require ESP transport" "$policy_blocks" '^src .* proto gre .*proto esp .* mode transport([[:space:]]|$)' 6
done

# Every directional direct spoke flow must move its own outbound ESP SA counter.
# Sample each exact state adjacently so a rekey cannot invalidate six baselines
# held across the complete traffic matrix. A retry always takes a new baseline.
for source in 1 2 3; do
    for destination in 1 2 3; do
        [[ "$source" == "$destination" ]] && continue
        counter_moved=false
        before=
        after=
        for attempt in 1 2 3; do
            before=$(xfrm_packets "spoke$source" "10.0.0.$((10 + source))" "10.0.0.$((10 + destination))")
            if [[ "$before" =~ ^[0-9]+$ ]]; then
                timeout 6 docker exec "$(container "spoke$source")" \
                    ping -I "192.168.${source}.1" -c 3 -W 1 \
                    "192.168.${destination}.1" >/dev/null 2>&1 || true
                after=$(xfrm_packets "spoke$source" "10.0.0.$((10 + source))" "10.0.0.$((10 + destination))")
                if [[ "$after" =~ ^[0-9]+$ ]] && (( after > before )); then
                    counter_moved=true
                    break
                fi
            fi
            (( attempt < 3 )) && sleep 1
        done
        if [[ "$counter_moved" == true ]]; then
            pass "spoke$source-to-spoke$destination moves its exact outbound ESP counter"
        else
            fail "spoke$source-to-spoke$destination moves its exact outbound ESP counter" 'no adjacent numeric counter increase after bounded retries'
        fi
    done
done

if transition=$(timeout 60 "$REPO_ROOT/labs/dmvpn-phase3-ipsec-capstone/capture-protected.sh" 2>&1); then
    pass 'bridge-wide transition proves hub-first ESP then direct ESP with zero raw GRE'
else
    fail 'bridge-wide transition proves hub-first ESP then direct ESP with zero raw GRE' "${transition//$'\n'/; }"
fi
if timeout 8 docker exec "$(container spoke1)" ping -I 192.168.1.1 -M 'do' -s 1360 \
    -c 2 -W 2 192.168.2.1 >/dev/null 2>&1; then
    pass 'meaningful 1360-byte DF payload crosses the protected 1400-MTU overlay'
else
    fail 'meaningful 1360-byte DF payload crosses the protected 1400-MTU overlay' 'bounded DF traffic failed'
fi

summary
