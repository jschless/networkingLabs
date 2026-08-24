#!/usr/bin/env bash
# Grade the exact healthy debug-gre-basics end state without changing config.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
# shellcheck source=state-lib.sh
source "$REPO_ROOT/labs/debug-gre-basics/state-lib.sh"
lab_init "debug-gre-basics"

assert_equal() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" "observed state differs from the exact lab contract"
    fi
}

assert_match() {
    local label=$1 actual=$2 pattern=$3
    if grep -qiE "$pattern" <<<"$actual"; then
        pass "$label"
    else
        fail "$label" "required evidence is absent"
    fi
}

assert_absent() {
    local label=$1 actual=$2 pattern=$3
    if ! grep -qiE "$pattern" <<<"$actual"; then
        pass "$label"
    else
        fail "$label" "unexpected state remains active"
    fi
}

assert_ping_linux() {
    local label=$1 node=$2 destination=$3
    if docker exec "$(debug_gre_container "$node")" \
        ping -c 2 -W 1 "$destination" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label" "the required path is not forwarding"
    fi
}

assert_ping_eos() {
    local label=$1 node=$2 destination=$3 output
    output=$(debug_gre_eos "$node" "ping $destination repeat 2 timeout 1")
    if grep -qE '(^|, )0% packet loss([[:space:]]|$)|^[[:space:]]*[0-9]+ bytes from ' \
        <<<"$output"; then
        pass "$label"
    else
        fail "$label" "the required path is not forwarding"
    fi
}

actual_nodes=$(docker ps --format '{{.Names}}' | sed -n \
    's/^clab-debug-gre-basics-//p' | LC_ALL=C sort)
assert_equal "inventory contains exactly the five intended nodes" "$actual_nodes" \
    $'gw-a\ngw-b\nhost-a\nhost-b\ninternet'

for node in gw-a gw-b; do
    assert_equal "$node uses native cEOS" \
        "$(docker inspect --format '{{.Config.Image}}' \
            "$(debug_gre_container "$node")" 2>/dev/null)" 'ceos:4.35.2F'
    assert_match "$node reports EOS 4.35.2F" \
        "$(debug_gre_eos "$node" 'show version')" '4\.35\.2F'
done
for node in host-a host-b internet; do
    assert_equal "$node uses the incidental Linux image" \
        "$(docker inspect --format '{{.Config.Image}}' \
            "$(debug_gre_container "$node")" 2>/dev/null)" 'ops-lab:local'
done

for node in host-a host-b internet; do
    mgmt_facts=$(debug_gre_mgmt_facts "$node")
    read -r mgmt_cidr _mgmt_gateway _mgmt_subnet <<<"$mgmt_facts"
    assert_equal "$node has exactly its Docker-generated eth0 address" \
        "$(debug_gre_linux_mgmt_address "$node")" "eth0 $mgmt_cidr"
    actual_mgmt_routes=$(debug_gre_linux_mgmt_routes "$node")
    expected_mgmt_routes=$(debug_gre_linux_expected_mgmt_routes "$node")
    assert_equal "$node eth0 route inventory is exact" \
        "$actual_mgmt_routes" "$expected_mgmt_routes"
    if [[ "$node" == internet ]]; then
        expected_mgmt_route_count=2
    else
        expected_mgmt_route_count=1
    fi
    assert_equal "$node has the exact management-route count" \
        "$(sed '/^$/d' <<<"$actual_mgmt_routes" | wc -l | tr -d ' ')" \
        "$expected_mgmt_route_count"
done

host_a_addresses=$(debug_gre_node host-a \
    "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print \$2, \$4}' | sort")
host_b_addresses=$(debug_gre_node host-b \
    "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print \$2, \$4}' | sort")
assert_equal "host-a owns only its intended data-plane address" \
    "$host_a_addresses" 'eth1 192.168.1.10/24'
assert_equal "host-b owns only its intended data-plane address" \
    "$host_b_addresses" 'eth1 192.168.2.10/24'

host_a_routes=$(debug_gre_node host-a \
    "ip -4 route show table main | grep -v ' dev eth0' | sort")
host_b_routes=$(debug_gre_node host-b \
    "ip -4 route show table main | grep -v ' dev eth0' | sort")
assert_match "host-a has its exact default gateway" "$host_a_routes" \
    '^default via 192\.168\.1\.1 dev eth1([[:space:]]|$)'
assert_match "host-a retains its connected LAN" "$host_a_routes" \
    '^192\.168\.1\.0/24 dev eth1 proto kernel scope link src 192\.168\.1\.10([[:space:]]|$)'
assert_equal "host-a has exactly two non-management routes" \
    "$(wc -l <<<"$host_a_routes" | tr -d ' ')" '2'
assert_match "host-b has its exact default gateway" "$host_b_routes" \
    '^default via 192\.168\.2\.1 dev eth1([[:space:]]|$)'
assert_match "host-b retains its connected LAN" "$host_b_routes" \
    '^192\.168\.2\.0/24 dev eth1 proto kernel scope link src 192\.168\.2\.10([[:space:]]|$)'
assert_equal "host-b has exactly two non-management routes" \
    "$(wc -l <<<"$host_b_routes" | tr -d ' ')" '2'

transit_addresses=$(debug_gre_node internet \
    "ip -4 -o address show scope global | awk '\$2 != \"eth0\" {print \$2, \$4}' | sort")
assert_equal "transit owns only the two intended WAN addresses" \
    "$transit_addresses" $'eth1 203.0.113.2/30\neth2 203.0.113.5/30'
assert_equal "transit IPv4 forwarding is enabled" \
    "$(debug_gre_node internet 'sysctl -n net.ipv4.ip_forward')" '1'
transit_routes=$(debug_gre_node internet \
    "ip -4 route show table main | grep -v ' dev eth0' | sort")
assert_match "transit retains the Site A connected route" "$transit_routes" \
    '^203\.0\.113\.0/30 dev eth1 proto kernel scope link src 203\.0\.113\.2([[:space:]]|$)'
assert_match "transit retains the Site B connected route" "$transit_routes" \
    '^203\.0\.113\.4/30 dev eth2 proto kernel scope link src 203\.0\.113\.5([[:space:]]|$)'
assert_equal "transit has exactly two non-management routes" \
    "$(wc -l <<<"$transit_routes" | tr -d ' ')" '2'

assert_equal "gw-a forwarding readiness completed" \
    "$(debug_gre_node gw-a 'cat /tmp/debug-gre-basics-eos-forward.ready')" 'ready:eth1'
assert_equal "gw-b forwarding readiness completed" \
    "$(debug_gre_node gw-b 'cat /tmp/debug-gre-basics-eos-forward.ready')" 'ready:eth2'
for item in 'gw-a eth1' 'gw-b eth2'; do
    node=${item%% *}
    interface=${item##* }
    if ! debug_gre_node "$node" \
        "iptables -w 1 -C EOS_FORWARD -i $interface -j DROP" >/dev/null; then
        pass "$node LAN-ingress DROP is absent"
    else
        fail "$node LAN-ingress DROP is absent" "forwarding readiness is incomplete"
    fi
done

for node in gw-a gw-b; do
    assert_equal "$node configured-interface inventory is exact" \
        "$(debug_gre_interface_names "$node")" \
        $'Ethernet1\nEthernet2\nLoopback0\nManagement0\nTunnel0'
    for interface in Loopback0 Ethernet1 Ethernet2 Tunnel0; do
        if debug_gre_interface_allowed "$node" "$interface" healthy; then
            pass "$node $interface has only the intended declarations"
        else
            fail "$node $interface has only the intended declarations" \
                "required state is missing or an extra declaration is present"
        fi
        if debug_gre_interface_up "$node" "$interface"; then
            pass "$node $interface is operationally up/up"
        else
            fail "$node $interface is operationally up/up" \
                "canonical config omits default no-shutdown, so operational state is required"
        fi
    done
    running_vrf_routes=$(debug_gre_vrf_routes "$node")
    saved_vrf_routes=$(debug_gre_vrf_routes "$node" saved)
    assert_equal "$node running VRF-route inventory is exactly empty" \
        "$running_vrf_routes" ''
    assert_equal "$node running VRF-route count is exact" \
        "$(sed '/^$/d' <<<"$running_vrf_routes" | wc -l | tr -d ' ')" '0'
    assert_equal "$node saved VRF-route inventory is exactly empty" \
        "$saved_vrf_routes" ''
    assert_equal "$node saved VRF-route count is exact" \
        "$(sed '/^$/d' <<<"$saved_vrf_routes" | wc -l | tr -d ' ')" '0'
    if debug_gre_saved_exact "$node"; then
        pass "$node saved startup remains the exact intentional incident"
    else
        fail "$node saved startup remains the exact intentional incident" \
            "the nonpersistent troubleshooting contract was violated"
    fi
    running_config=$(debug_gre_eos "$node" 'show running-config')
    assert_absent "$node has no dynamic-routing process" "$running_config" \
        '^router[[:space:]]'
    if debug_gre_runtime_detail_exact "$node" healthy; then
        pass "$node operational Tunnel0 source/destination is exact"
    else
        fail "$node operational Tunnel0 source/destination is exact" \
            "runtime tunnel endpoint evidence differs"
    fi
    tunnel_detail=$(debug_gre_eos "$node" 'show interfaces Tunnel0')
    assert_absent "$node has no recursive tunnel resolution" "$tunnel_detail" \
        'recursive route resolution loop|resolved over another tunnel'
done

assert_equal "gw-a static-route inventory is exact" \
    "$(debug_gre_routes gw-a)" \
    $'ip route 0.0.0.0/0 203.0.113.2\nip route 192.168.2.0/24 172.16.0.2'
assert_equal "gw-b static-route inventory is exact" \
    "$(debug_gre_routes gw-b)" \
    $'ip route 0.0.0.0/0 203.0.113.5\nip route 192.168.1.0/24 172.16.0.1'

assert_ping_eos "gw-a reaches its near transit next hop" gw-a 203.0.113.2
assert_ping_eos "gw-a reaches the far public WAN endpoint" gw-a 203.0.113.6
assert_ping_eos "gw-b reaches its near transit next hop" gw-b 203.0.113.5
assert_ping_eos "gw-b reaches the far public WAN endpoint" gw-b 203.0.113.1
assert_ping_eos "gw-a reaches gw-b through Tunnel0" gw-a 172.16.0.2
assert_ping_eos "gw-b reaches gw-a through Tunnel0" gw-b 172.16.0.1
assert_ping_linux "Site A reaches Site B through GRE" host-a 192.168.2.10
assert_ping_linux "Site B reaches Site A through GRE" host-b 192.168.1.10

summary
