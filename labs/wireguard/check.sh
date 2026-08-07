#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "wireguard"

check_equal() {
    local name="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected '$expected', got '$actual'"
    fi
}

container_image() {
    docker inspect "clab-${TOPO_NAME}-$1" --format '{{.Config.Image}}' 2>/dev/null
}

valid_key() {
    [[ "$1" =~ ^[A-Za-z0-9+/]{43}=$ ]]
}

recent_timestamp() {
    local timestamp="$1" now
    now="$(date +%s)"
    [[ "$timestamp" =~ ^[0-9]+$ ]] &&
        (( timestamp > 0 && now >= timestamp && now - timestamp <= 180 ))
}

positive_transfers() {
    local output="$1" expected_rows="$2" rows=0 key received sent
    while read -r key received sent; do
        [[ -n "$key" ]] || continue
        [[ "$received" =~ ^[0-9]+$ && "$sent" =~ ^[0-9]+$ ]] || return 1
        (( received > 0 && sent > 0 )) || return 1
        (( rows++ )) || true
    done <<< "$output"
    (( rows == expected_rows ))
}

expected_inventory="$(printf '%s\n' \
    clab-wireguard-gw-a \
    clab-wireguard-gw-b \
    clab-wireguard-hub \
    clab-wireguard-wan | sort)"
actual_inventory="$(docker ps --format '{{.Names}}' | grep '^clab-wireguard-' | sort)"
check_equal "exact four-container inventory" "$actual_inventory" "$expected_inventory"

check_equal "hub image" "$(container_image hub)" "wireguard-lab:local"
check_equal "gw-a image" "$(container_image gw-a)" "wireguard-lab:local"
check_equal "gw-b image" "$(container_image gw-b)" "wireguard-lab:local"
check_equal "WAN image" "$(container_image wan)" "ops-lab:local"

wan_ports="$(node wan 'ip -o link show master br-wan')"
if [[ "$(grep -Ec 'eth[123](@|:)' <<< "$wan_ports")" -eq 3 ]] &&
   grep -qE 'eth1(@|:)' <<< "$wan_ports" &&
   grep -qE 'eth2(@|:)' <<< "$wan_ports" &&
   grep -qE 'eth3(@|:)' <<< "$wan_ports"; then
    pass "internal WAN bridge has three data ports"
else
    fail "internal WAN bridge has three data ports" "expected eth1, eth2, and eth3 on br-wan"
fi

check_contains "hub WAN address" "$(node hub 'ip -4 -o address show dev eth1')" 'inet 10\.0\.0\.1/24 '
check_contains "gw-a WAN address" "$(node gw-a 'ip -4 -o address show dev eth1')" 'inet 10\.0\.0\.10/24 '
check_contains "gw-b WAN address" "$(node gw-b 'ip -4 -o address show dev eth1')" 'inet 10\.0\.0\.20/24 '

if node gw-a 'ping -c 2 -W 2 10.0.0.1' >/dev/null &&
   node gw-b 'ping -c 2 -W 2 10.0.0.1' >/dev/null &&
   node gw-a 'ping -c 2 -W 2 10.0.0.20' >/dev/null; then
    pass "WAN transport reachability"
else
    fail "WAN transport reachability" "one or more transport probes failed"
fi

for node_name in hub gw-a gw-b; do
    case "$node_name" in
        hub) expected_address='192\.168\.100\.1/24' ;;
        gw-a) expected_address='192\.168\.100\.10/32' ;;
        gw-b) expected_address='192\.168\.100\.20/32' ;;
    esac
    link_state="$(node "$node_name" 'ip -o link show dev wg0')"
    address_state="$(node "$node_name" 'ip -4 -o address show dev wg0')"
    if grep -qE '<[^>]*UP[^>]*>' <<< "$link_state" &&
       grep -qE "inet ${expected_address} " <<< "$address_state"; then
        pass "$node_name wg0 up with exact address"
    else
        fail "$node_name wg0 up with exact address" "interface or address does not match"
    fi
done

hub_key="$(node hub 'wg show wg0 public-key')"
gw_a_key="$(node gw-a 'wg show wg0 public-key')"
gw_b_key="$(node gw-b 'wg show wg0 public-key')"

for node_name in hub gw-a gw-b; do
    case "$node_name" in
        hub) live_key="$hub_key" ;;
        gw-a) live_key="$gw_a_key" ;;
        gw-b) live_key="$gw_b_key" ;;
    esac
    material_modes="$(node "$node_name" 'stat -c "%a" /etc/wireguard/private.key /etc/wireguard/public.key /etc/wireguard/wg0.conf')"
    stored_public="$(node "$node_name" 'cat /etc/wireguard/public.key')"
    derived_public="$(node "$node_name" 'wg pubkey < /etc/wireguard/private.key')"
    config_public="$(node "$node_name" '
        set -euo pipefail
        temporary_interface="wgck$$"
        cleanup() {
            ip link delete "$temporary_interface" >/dev/null 2>&1 || true
        }
        trap cleanup EXIT
        test -s /etc/wireguard/wg0.conf
        ip link add "$temporary_interface" type wireguard
        wg-quick strip wg0 | wg setconf "$temporary_interface" /dev/stdin
        wg show "$temporary_interface" public-key
    ')"
    if [[ "$material_modes" == $'600\n600\n600' ]] &&
       valid_key "$stored_public" &&
       [[ "$derived_public" == "$stored_public" &&
          "$config_public" == "$stored_public" &&
          "$stored_public" == "$live_key" ]]; then
        pass "$node_name protected key/config continuity"
    else
        fail "$node_name protected key/config continuity" "expected nonempty valid mode-600 config/key files with matching private, config, stored, and live identities"
    fi
done

if valid_key "$hub_key" && valid_key "$gw_a_key" && valid_key "$gw_b_key" &&
   [[ "$hub_key" != "$gw_a_key" && "$hub_key" != "$gw_b_key" && "$gw_a_key" != "$gw_b_key" ]]; then
    pass "three distinct valid public identities"
else
    fail "three distinct valid public identities" "public keys are absent, malformed, or reused"
fi

hub_peers="$(node hub 'wg show wg0 peers' | sort)"
expected_hub_peers="$(printf '%s\n' "$gw_a_key" "$gw_b_key" | sort)"
if [[ "$(node hub 'wg show wg0 listen-port')" == "51820" && "$hub_peers" == "$expected_hub_peers" ]]; then
    pass "hub listen port and exact peer identities"
else
    fail "hub listen port and exact peer identities" "expected UDP/51820 and exactly both spoke keys"
fi

hub_allowed="$(node hub 'wg show wg0 allowed-ips')"
hub_gw_a_prefix="$(awk -v key="$gw_a_key" '$1 == key {print $2}' <<< "$hub_allowed")"
hub_gw_b_prefix="$(awk -v key="$gw_b_key" '$1 == key {print $2}' <<< "$hub_allowed")"
if [[ "$hub_gw_a_prefix" == "192.168.100.10/32" && "$hub_gw_b_prefix" == "192.168.100.20/32" ]]; then
    pass "hub exact spoke prefix ownership"
else
    fail "hub exact spoke prefix ownership" "expected gw-a .10/32 and gw-b .20/32"
fi

if [[ "$(node gw-a 'wg show wg0 peers')" == "$hub_key" &&
      "$(node gw-b 'wg show wg0 peers')" == "$hub_key" ]]; then
    pass "spokes enroll only the hub identity"
else
    fail "spokes enroll only the hub identity" "expected exactly one hub peer on each spoke"
fi

gw_a_endpoint="$(node gw-a 'wg show wg0 endpoints' | awk -v key="$hub_key" '$1 == key {print $2}')"
gw_b_endpoint="$(node gw-b 'wg show wg0 endpoints' | awk -v key="$hub_key" '$1 == key {print $2}')"
if [[ "$gw_a_endpoint" == "10.0.0.1:51820" && "$gw_b_endpoint" == "10.0.0.1:51820" ]]; then
    pass "spoke exact hub endpoints"
else
    fail "spoke exact hub endpoints" "expected 10.0.0.1:51820 on both spokes"
fi

gw_a_allowed="$(node gw-a 'wg show wg0 allowed-ips' | awk -v key="$hub_key" '$1 == key {print $2}')"
gw_b_allowed="$(node gw-b 'wg show wg0 allowed-ips' | awk -v key="$hub_key" '$1 == key {print $2}')"
if [[ "$gw_a_allowed" == "192.168.100.0/24" && "$gw_b_allowed" == "192.168.100.0/24" ]]; then
    pass "spoke exact overlay mapping"
else
    fail "spoke exact overlay mapping" "expected the hub peer to own 192.168.100.0/24"
fi

gw_a_keepalive="$(node gw-a 'wg show wg0 persistent-keepalive' | awk -v key="$hub_key" '$1 == key {print $2}')"
gw_b_keepalive="$(node gw-b 'wg show wg0 persistent-keepalive' | awk -v key="$hub_key" '$1 == key {print $2}')"
if [[ "$gw_a_keepalive" == "25" && "$gw_b_keepalive" == "25" ]]; then
    pass "spoke lab keepalives"
else
    fail "spoke lab keepalives" "expected 25-second keepalive on each spoke"
fi

hub_route="$(node hub 'ip -4 route show 192.168.100.0/24')"
gw_a_route="$(node gw-a 'ip -4 route show 192.168.100.0/24')"
gw_b_route="$(node gw-b 'ip -4 route show 192.168.100.0/24')"
if grep -qE '^192\.168\.100\.0/24 dev wg0 ' <<< "$hub_route" &&
   grep -qE '^192\.168\.100\.0/24 dev wg0 ' <<< "$gw_a_route" &&
   grep -qE '^192\.168\.100\.0/24 dev wg0 ' <<< "$gw_b_route" &&
   [[ "$(node hub 'cat /proc/sys/net/ipv4/ip_forward')" == "1" ]]; then
    pass "overlay routes and hub forwarding"
else
    fail "overlay routes and hub forwarding" "route or IPv4 forwarding state is incomplete"
fi

# Seed bounded traffic before checking liveness and byte counters.
node hub 'ping -c 2 -W 2 192.168.100.10' >/dev/null || true
node hub 'ping -c 2 -W 2 192.168.100.20' >/dev/null || true
node gw-a 'ping -c 2 -W 2 192.168.100.1' >/dev/null || true
node gw-b 'ping -c 2 -W 2 192.168.100.1' >/dev/null || true
node gw-a 'ping -c 2 -W 2 192.168.100.20' >/dev/null || true

hub_gw_a_latest="$(node hub 'wg show wg0 latest-handshakes' | awk -v key="$gw_a_key" '$1 == key {print $2}')"
hub_gw_b_latest="$(node hub 'wg show wg0 latest-handshakes' | awk -v key="$gw_b_key" '$1 == key {print $2}')"
gw_a_latest="$(node gw-a 'wg show wg0 latest-handshakes' | awk -v key="$hub_key" '$1 == key {print $2}')"
gw_b_latest="$(node gw-b 'wg show wg0 latest-handshakes' | awk -v key="$hub_key" '$1 == key {print $2}')"
if recent_timestamp "$hub_gw_a_latest" && recent_timestamp "$hub_gw_b_latest" &&
   recent_timestamp "$gw_a_latest" && recent_timestamp "$gw_b_latest"; then
    pass "recent authenticated handshakes"
else
    fail "recent authenticated handshakes" "one or more peer handshakes is absent or older than 180 seconds"
fi

if positive_transfers "$(node hub 'wg show wg0 transfer')" 2 &&
   positive_transfers "$(node gw-a 'wg show wg0 transfer')" 1 &&
   positive_transfers "$(node gw-b 'wg show wg0 transfer')" 1; then
    pass "nonzero bidirectional WireGuard transfer counters"
else
    fail "nonzero bidirectional WireGuard transfer counters" "expected sent and received bytes for every peer"
fi

if node hub 'ping -c 3 -W 2 192.168.100.10' >/dev/null &&
   node hub 'ping -c 3 -W 2 192.168.100.20' >/dev/null; then
    pass "hub-to-spoke overlay paths"
else
    fail "hub-to-spoke overlay paths" "one or more hub probes failed"
fi

if node gw-a 'ping -c 3 -W 2 192.168.100.1' >/dev/null &&
   node gw-b 'ping -c 3 -W 2 192.168.100.1' >/dev/null; then
    pass "spoke-to-hub overlay paths"
else
    fail "spoke-to-hub overlay paths" "one or more spoke probes failed"
fi

if node gw-a 'ping -c 3 -W 2 192.168.100.20' >/dev/null &&
   node gw-b 'ping -c 3 -W 2 192.168.100.10' >/dev/null; then
    pass "forwarded spoke-to-spoke overlay paths"
else
    fail "forwarded spoke-to-spoke overlay paths" "one or more forwarded probes failed"
fi

summary
