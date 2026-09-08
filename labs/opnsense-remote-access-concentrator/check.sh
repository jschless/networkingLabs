#!/usr/bin/env bash
# Secret-safe exact grader for native OPNsense remote-access concentration.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "opnsense-remote-access-concentrator"

lab_dir="$REPO_ROOT/labs/opnsense-remote-access-concentrator"
# shellcheck source=labs/opnsense-remote-access-concentrator/lab-lib.sh
source "$lab_dir/lab-lib.sh"

assert_flag() {
    local label=$1 output=$2 key=$3
    if grep -qxF "$key=1" <<<"$output"; then
        pass "$label"
    else
        fail "$label" "expected state is absent or inconsistent"
    fi
}

assert_exact() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" "expected state is absent or inconsistent"
    fi
}

client_grade() {
    local node=$1 expected_address=$2 expected_public_address=$3 server_public=$4
    docker exec -i \
        -e RA_EXPECTED_ADDRESS="$expected_address" \
        -e RA_EXPECTED_PUBLIC_ADDRESS="$expected_public_address" \
        -e RA_SERVER_PUBLIC="$server_public" \
        "$RA_PREFIX-$node" bash -s <<'EOF' 2>/dev/null || true
set -uo pipefail
runtime=/run/opnsense-ra-lab
emit() { printf '%s=%s\n' "$1" "$([[ $2 == true ]] && printf 1 || printf 0)"; }
valid_key() { [[ ${1:-} =~ ^[A-Za-z0-9+/]{43}=$ ]]; }

files=false
if [[ -d "$runtime" && "$(stat -c '%a' "$runtime" 2>/dev/null)" == 700 ]]; then
    inventory=$(find "$runtime" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)
    expected=$(printf '%s\n' private.key public.key wg0.conf | sort)
    modes=$(stat -c '%a' "$runtime/private.key" "$runtime/public.key" "$runtime/wg0.conf" 2>/dev/null || true)
    [[ "$inventory" == "$expected" && "$modes" == $'600\n600\n600' ]] && files=true
fi
emit files "$files"

continuity=false
config=false
if [[ "$files" == true ]]; then
    stored=$(<"$runtime/public.key")
    derived=$(wg pubkey <"$runtime/private.key" 2>/dev/null || true)
    config_private=$(sed -n 's/^PrivateKey = //p' "$runtime/wg0.conf")
    config_derived=$(printf '%s\n' "$config_private" | wg pubkey 2>/dev/null || true)
    live=$(wg show wg0 public-key 2>/dev/null || true)
    if valid_key "$stored" && [[ "$stored" == "$derived" && "$stored" == "$config_derived" && "$stored" == "$live" ]]; then
        continuity=true
    fi
    if [[ "$(wc -l <"$runtime/wg0.conf")" == 9 \
        && "$(grep -c '^\[Interface\]$' "$runtime/wg0.conf" || true)" == 1 \
        && "$(grep -c '^\[Peer\]$' "$runtime/wg0.conf" || true)" == 1 \
        && "$(grep -c "^Address = $RA_EXPECTED_ADDRESS$" "$runtime/wg0.conf" || true)" == 1 \
        && "$(grep -c '^PrivateKey = [A-Za-z0-9+/]\{43\}=$' "$runtime/wg0.conf" || true)" == 1 \
        && "$(grep -c "^PublicKey = $RA_SERVER_PUBLIC$" "$runtime/wg0.conf" || true)" == 1 \
        && "$(grep -c '^Endpoint = 203\.0\.113\.2:51820$' "$runtime/wg0.conf" || true)" == 1 \
        && "$(grep -c '^AllowedIPs = 10\.70\.10\.0/24$' "$runtime/wg0.conf" || true)" == 1 \
        && "$(grep -c '^PersistentKeepalive = 5$' "$runtime/wg0.conf" || true)" == 1 ]]; then
        config=true
    fi
fi
emit continuity "$continuity"
emit config "$config"

interface=false
if ip -o link show dev wg0 2>/dev/null | grep -q '<[^>]*UP[^>]*>' \
    && ip -o -4 address show dev wg0 2>/dev/null | grep -q "inet $RA_EXPECTED_ADDRESS "; then
    interface=true
fi
emit interface "$interface"

peer=false
endpoint=false
allowed=false
keepalive=false
handshake=false
transfer=false
if [[ "$interface" == true ]]; then
    [[ "$(wg show wg0 peers 2>/dev/null)" == "$RA_SERVER_PUBLIC" ]] && peer=true
    [[ "$(wg show wg0 endpoints 2>/dev/null | awk -v key="$RA_SERVER_PUBLIC" '$1 == key {print $2}')" == "203.0.113.2:51820" ]] && endpoint=true
    [[ "$(wg show wg0 allowed-ips 2>/dev/null | awk -v key="$RA_SERVER_PUBLIC" '$1 == key {print $2}')" == "10.70.10.0/24" ]] && allowed=true
    [[ "$(wg show wg0 persistent-keepalive 2>/dev/null | awk -v key="$RA_SERVER_PUBLIC" '$1 == key {print $2}')" == "5" ]] && keepalive=true
    latest=$(wg show wg0 latest-handshakes 2>/dev/null | awk -v key="$RA_SERVER_PUBLIC" '$1 == key {print $2}')
    now=$(date +%s)
    [[ "$latest" =~ ^[0-9]+$ ]] && (( latest > 0 && now >= latest && now - latest <= 180 )) && handshake=true
    read -r _ received sent < <(wg show wg0 transfer 2>/dev/null || true)
    [[ "$received" =~ ^[0-9]+$ && "$sent" =~ ^[0-9]+$ ]] \
        && (( received > 0 && sent > 0 )) && transfer=true
fi
emit peer "$peer"
emit endpoint "$endpoint"
emit allowed "$allowed"
emit keepalive "$keepalive"
emit handshake "$handshake"
emit transfer "$transfer"

routes=false
corp_route=$(ip -4 route get 10.70.10.10 2>/dev/null || true)
public_route=$(ip -4 route get 203.0.113.2 2>/dev/null || true)
default_route=$(ip -4 route show default 2>/dev/null || true)
if grep -qE "10\.70\.10\.10 dev wg0 .*src ${RA_EXPECTED_ADDRESS%/*}([[:space:]]|$)" <<<"$corp_route" \
    && grep -qE "203\.0\.113\.2 dev eth1 .*src $RA_EXPECTED_PUBLIC_ADDRESS([[:space:]]|$)" <<<"$public_route" \
    && grep -qxE '^default via 203\.0\.113\.2 dev eth1([[:space:]].*)?$' <<<"$default_route"; then
    routes=true
fi
emit routes "$routes"
EOF
}

if ra_require_tools >/dev/null 2>&1; then
    pass "required host tooling is available"
else
    fail "required host tooling is available" "one or more runtime dependencies are missing"
fi

expected_inventory=$(printf '%s\n' \
    "$RA_PREFIX-contractor" "$RA_PREFIX-corp-app" "$RA_PREFIX-developer" "$RA_PREFIX-jump-host" | sort)
actual_inventory=$(docker ps --format '{{.Names}}' | grep "^${RA_PREFIX}-" | sort || true)
assert_exact "exact four-container inventory" "$actual_inventory" "$expected_inventory"

for node_image in \
    'developer|wireguard-lab:local' \
    'contractor|wireguard-lab:local' \
    'corp-app|ops-lab:local' \
    'jump-host|ops-lab:local'; do
    node_name=${node_image%%|*}
    expected_image=${node_image#*|}
    actual_image=$(docker inspect --format '{{.Config.Image}}' "$RA_PREFIX-$node_name" 2>/dev/null || true)
    assert_exact "$node_name uses its exact role image" "$actual_image" "$expected_image"
done

if ra_ssh_ready; then
    pass "OPNsense management is ready"
else
    fail "OPNsense management is ready" "loopback-only management probe failed"
fi

developer_public=$(ra_client_public developer)
contractor_public=$(ra_client_public contractor)
server_public=$(ra_server_public)
if ra_valid_public_key "$developer_public" \
    && ra_valid_public_key "$contractor_public" \
    && ra_valid_public_key "$server_public" \
    && [[ "$developer_public" != "$contractor_public" \
        && "$developer_public" != "$server_public" \
        && "$contractor_public" != "$server_public" ]]; then
    pass "three distinct public identities"
else
    fail "three distinct public identities" "expected state is absent or inconsistent"
fi

saved=$(ra_php grade "$developer_public" "$contractor_public" "$lab_dir/grade-config.php" 2>/dev/null || true)
for check in \
    'input_keys|saved public-key correlation' \
    'interfaces|saved data-interface state' \
    'wg_registered|saved WireGuard interface registration' \
    'legacy_rules|saved WAN foundation policy' \
    'general|saved native WireGuard service state' \
    'client_inventory|saved peer cardinality and identities' \
    'developer|saved developer peer ownership' \
    'contractor|saved contractor peer ownership' \
    'server|saved server instance, relation, and key consistency' \
    'firewall|saved five-rule post-auth policy'; do
    key=${check%%|*}
    label=${check#*|}
    assert_flag "$label" "$saved" "$key"
done

developer_state=$(client_grade developer 10.250.0.10/32 203.0.113.10 "$server_public")
contractor_state=$(client_grade contractor 10.250.0.20/32 203.0.113.20 "$server_public")
for check in \
    'files|protected runtime inventory and modes' \
    'continuity|private/config/stored/live key continuity' \
    'config|exact split-tunnel client configuration' \
    'interface|live wg0 address and link' \
    'peer|single concentrator peer identity' \
    'endpoint|public concentrator endpoint' \
    'allowed|exact split-tunnel AllowedIPs' \
    'keepalive|five-second persistent keepalive' \
    'routes|split-route selection and public continuity'; do
    key=${check%%|*}
    label=${check#*|}
    assert_flag "developer $label" "$developer_state" "$key"
    assert_flag "contractor $label" "$contractor_state" "$key"
done

corp_state=$(docker exec "$RA_PREFIX-corp-app" sh -c \
    'ip -o -4 addr show dev eth1; ip -4 route show default; pgrep -af "^python3 /tcp-responder.py 8443 corp-application$"' \
    2>/dev/null || true)
jump_state=$(docker exec "$RA_PREFIX-jump-host" sh -c \
    'ip -o -4 addr show dev eth1; ip -4 route show default; pgrep -af "^python3 /tcp-responder.py 22 jump-host$"' \
    2>/dev/null || true)
if grep -q 'inet 10.70.10.10/24 ' <<<"$corp_state" \
    && grep -qE '^default via 10\.70\.10\.1 dev eth1([[:space:]]|$)' <<<"$corp_state" \
    && grep -q 'python3 /tcp-responder.py 8443 corp-application' <<<"$corp_state"; then
    pass "corp application scaffold and service are exact"
else
    fail "corp application scaffold and service are exact" "incidental service state is inconsistent"
fi
if grep -q 'inet 10.70.10.20/24 ' <<<"$jump_state" \
    && grep -qE '^default via 10\.70\.10\.1 dev eth1([[:space:]]|$)' <<<"$jump_state" \
    && grep -q 'python3 /tcp-responder.py 22 jump-host' <<<"$jump_state"; then
    pass "jump host scaffold and service are exact"
else
    fail "jump host scaffold and service are exact" "incidental service state is inconsistent"
fi

if docker exec "$RA_PREFIX-developer" ping -c 2 -W 2 203.0.113.2 >/dev/null 2>&1 \
    && docker exec "$RA_PREFIX-contractor" ping -c 2 -W 2 203.0.113.2 >/dev/null 2>&1; then
    pass "public underlay continuity from both clients"
else
    fail "public underlay continuity from both clients" "traffic probe did not succeed"
fi

if ra_tcp_expect developer 10.70.10.10 8443 corp-application; then
    pass "developer reaches the application service"
else
    fail "developer reaches the application service" "traffic probe did not succeed"
fi
if ra_tcp_expect developer 10.70.10.20 22 jump-host; then
    pass "developer reaches the jump service"
else
    fail "developer reaches the jump service" "traffic probe did not succeed"
fi
if ra_tcp_expect contractor 10.70.10.20 22 jump-host; then
    pass "contractor reaches only the entitled service"
else
    fail "contractor reaches only the entitled service" "traffic probe did not succeed"
fi
if ra_tcp_denied contractor 10.70.10.10 8443; then
    pass "contractor is denied from the application service"
else
    fail "contractor is denied from the application service" "traffic probe unexpectedly succeeded"
fi
if ra_tcp_denied developer 10.70.10.1 443 \
    && ra_tcp_denied contractor 10.70.10.1 443; then
    pass "both VPN identities are denied from firewall management"
else
    fail "both VPN identities are denied from firewall management" "traffic probe unexpectedly succeeded"
fi

# Service and denial probes above seed handshake, transfer, state, and log data.
live=$(ra_php grade "$developer_public" "$contractor_public" "$lab_dir/grade-live.php" 2>/dev/null || true)
for check in \
    'platform|live OPNsense platform' \
    'interfaces|live WAN, CORP, and wg0 interfaces' \
    'routes|live per-peer server routes' \
    'server|live server identity and listen port' \
    'peer_inventory|live peer identity cardinality' \
    'allowed_ips|live peer-to-inner-address ownership' \
    'handshakes|recent authenticated handshakes' \
    'transfers|nonzero bidirectional peer transfers' \
    'pf_inventory|live five-rule policy order' \
    'pf_scope|live policy action, scope, ports, and logging' \
    'denial_counters|live logged-denial counters'; do
    key=${check%%|*}
    label=${check#*|}
    assert_flag "$label" "$live" "$key"
done

# Re-read liveness after traffic generation rather than accepting stale data.
developer_after=$(client_grade developer 10.250.0.10/32 203.0.113.10 "$server_public")
contractor_after=$(client_grade contractor 10.250.0.20/32 203.0.113.20 "$server_public")
for check in 'handshake|recent live handshake' 'transfer|nonzero bidirectional transfer'; do
    key=${check%%|*}
    label=${check#*|}
    assert_flag "developer $label" "$developer_after" "$key"
    assert_flag "contractor $label" "$contractor_after" "$key"
done

summary
