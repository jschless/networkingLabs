#!/usr/bin/env bash
# Deterministic, configuration-read-only end-state assertions. A solved lab is
# 52/52. The supported fault preserves BGP and the VIP route while five narrow
# service/coupling/client assertions fail.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "anycast-dns"

PREFIX="clab-${TOPO_NAME}"
EOS_BUILD_ID='6f39e5bb-e6c7-4637-b931-ecb30d43e034'

container() {
    printf '%s-%s\n' "$PREFIX" "$1"
}

check_equals() {
    local name="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected '${expected}', got '${actual:-<empty>}'"
    fi
}

check_image() {
    local node_name="$1" expected="$2" actual
    actual="$(docker inspect --format '{{.Config.Image}}' \
        "$(container "$node_name")" 2>/dev/null)"
    check_equals "$node_name uses its exact image reference" "$actual" "$expected"
}

json_matches() {
    local payload="$1" program="$2"
    python3 -c "$program" <<<"$payload" >/dev/null 2>&1
}

whoami_from() {
    docker exec "$(container "$1")" dig +time=2 +tries=1 +short \
        @"$2" TXT whoami.lab.test 2>/dev/null | tr -d '"'
}

data_from() {
    docker exec "$(container "$1")" dig +time=2 +tries=1 +short \
        @"$2" www.lab.test 2>/dev/null
}

check_eos_runtime() {
    local node_name="$1" image_id architecture version_text version_json
    image_id="$(docker inspect --format '{{.Image}}' "$(container "$node_name")" \
        2>/dev/null)"
    architecture="$(docker image inspect --format '{{.Architecture}}' \
        "$image_id" 2>/dev/null)"
    version_text="$(eos "$node_name" 'show version')"
    version_json="$(eos "$node_name" 'show version | json')"
    case "$architecture" in
        amd64)
            if EOS_BUILD_ID="$EOS_BUILD_ID" json_matches "$version_json" '
import json, os, sys
d = json.load(sys.stdin)
values = []
def collect(value):
    if isinstance(value, dict):
        for item in value.values(): collect(item)
    elif isinstance(value, list):
        for item in value: collect(item)
    elif isinstance(value, str):
        values.append(value)
collect(d)
ok = ("4.35.2F-46221466.4352F" in values
      and os.environ["EOS_BUILD_ID"] in values)
raise SystemExit(0 if ok else 1)
' || { grep -q '4\.35\.2F-46221466\.4352F' <<<"$version_text" \
                && grep -q "$EOS_BUILD_ID" <<<"$version_text"; }; then
                pass "$node_name amd64 runtime is exact EOS 4.35.2F engineering build"
            else
                fail "$node_name amd64 runtime is exact EOS 4.35.2F engineering build" \
                    "software version or build ID differs"
            fi
            ;;
        arm64)
            if json_matches "$version_json" '
import json, re, sys
d = json.load(sys.stdin)
values = []
def collect(value):
    if isinstance(value, dict):
        for item in value.values(): collect(item)
    elif isinstance(value, list):
        for item in value: collect(item)
    elif isinstance(value, str):
        values.append(value)
collect(d)
release = any(re.search(r"(^|[^0-9.])4\.36\.1F([^0-9.]|$)", value)
              for value in values)
architecture = any(re.search(r"(^|[^a-z0-9])(arm64|aarch64|armv8)([^a-z0-9]|$)",
                             value, re.IGNORECASE)
                   for value in values)
raise SystemExit(0 if release and architecture else 1)
' || { grep -qE '(^|[^0-9.])4\.36\.1F([^0-9.]|$)' <<<"$version_text" \
                && grep -qiE '(^|[^a-z0-9])(arm64|aarch64|armv8)([^a-z0-9]|$)' \
                    <<<"$version_text"; }; then
                pass "$node_name arm64 runtime reports supported EOS 4.36.1F"
            else
                fail "$node_name arm64 runtime reports supported EOS 4.36.1F" \
                    "release line or reported architecture differs"
            fi
            ;;
        *)
            fail "$node_name runtime uses a supported cEOS architecture" \
                "expected amd64 or arm64, got '${architecture:-<empty>}'"
            ;;
    esac
}

# 1-7: topology and image identity.
running=0
for node_name in r1 r2 dns1 dns2 c1 c2; do
    [[ "$(docker inspect --format '{{.State.Running}}' \
        "$(container "$node_name")" 2>/dev/null)" == true ]] \
        && running=$((running + 1))
done
check_equals "all six expected containers are running" "$running" "6"
check_image r1 ceos:4.35.2F
check_image r2 ceos:4.35.2F
check_image dns1 anycast-dns:local
check_image dns2 anycast-dns:local
check_image c1 ops-lab:local
check_image c2 ops-lab:local

# 8-17: architecture-aware platform and package identity.
check_eos_runtime r1
check_eos_runtime r2
for resolver in dns1 dns2; do
    alpine="$(docker exec "$(container "$resolver")" \
        cat /etc/alpine-release 2>/dev/null)"
    check_equals "$resolver runs exact Alpine 3.16.2" "$alpine" "3.16.2"
done
for resolver in dns1 dns2; do
    frr_version="$(frr "$resolver" 'show version')"
    check_contains "$resolver reports the observed FRRouting 8.4_git runtime" \
        "$frr_version" '^FRRouting 8\.4_git'
done
expected_packages=$'bash-5.1.16-r2\nbind-tools-9.16.48-r0\ndnsmasq-2.86-r4'
for resolver in dns1 dns2; do
    packages="$(docker exec "$(container "$resolver")" \
        sh -c "apk list --installed 2>/dev/null | awk '\$1 ~ /^bash-[0-9]/ || \$1 ~ /^bind-tools-[0-9]/ || \$1 ~ /^dnsmasq-[0-9]/ {print \$1}' | sort" \
        2>/dev/null)"
    check_equals "$resolver uses exact shell, DNS client, and DNS daemon packages" \
        "$packages" "$expected_packages"
done
for client in c1 c2; do
    alpine="$(docker exec "$(container "$client")" \
        cat /etc/alpine-release 2>/dev/null)"
    check_equals "$client runs exact Alpine 3.20.10" "$alpine" "3.20.10"
done

# 18-27: exact baseline addressing and resolver health.
r1_config="$(eos r1 'show running-config')"
r2_config="$(eos r2 'show running-config')"
if grep -qE '^[[:space:]]+ip address 10\.0\.0\.1/32$' <<<"$r1_config" \
    && grep -qE '^[[:space:]]+ip address 10\.0\.12\.1/30$' <<<"$r1_config" \
    && grep -qE '^[[:space:]]+ip address 10\.0\.101\.1/30$' <<<"$r1_config" \
    && grep -qE '^[[:space:]]+ip address 172\.16\.1\.1/24$' <<<"$r1_config"; then
    pass "r1 retains the exact native baseline addresses"
else
    fail "r1 retains the exact native baseline addresses" "interface addressing differs"
fi
if grep -qE '^[[:space:]]+ip address 10\.0\.0\.2/32$' <<<"$r2_config" \
    && grep -qE '^[[:space:]]+ip address 10\.0\.12\.2/30$' <<<"$r2_config" \
    && grep -qE '^[[:space:]]+ip address 10\.0\.102\.1/30$' <<<"$r2_config" \
    && grep -qE '^[[:space:]]+ip address 172\.16\.2\.1/24$' <<<"$r2_config"; then
    pass "r2 retains the exact native baseline addresses"
else
    fail "r2 retains the exact native baseline addresses" "interface addressing differs"
fi
for spec in 'dns1 10.0.0.11/32 10.0.101.2/30 10.0.101.1' \
            'dns2 10.0.0.12/32 10.0.102.2/30 10.0.102.1'; do
    read -r resolver unique uplink gateway <<<"$spec"
    addresses="$(docker exec "$(container "$resolver")" ip -o -4 address show 2>/dev/null)"
    routes_json="$(docker exec "$(container "$resolver")" \
        ip -j route show 172.16.0.0/16 2>/dev/null)"
    if grep -qF "$unique" <<<"$addresses" \
        && grep -qF "$uplink" <<<"$addresses" \
        && GATEWAY="$gateway" json_matches "$routes_json" '
import json, os, sys
routes = json.load(sys.stdin)
ok = (len(routes) == 1
      and routes[0].get("dst") == "172.16.0.0/16"
      and routes[0].get("gateway") == os.environ["GATEWAY"]
      and routes[0].get("dev") == "eth1")
raise SystemExit(0 if ok else 1)
'; then
        pass "$resolver retains its exact unique, uplink, and client return-route baseline"
    else
        fail "$resolver retains its exact unique, uplink, and client return-route baseline" \
            "address or return route differs"
    fi
done
for spec in 'c1 172.16.1.10/24 172.16.1.1' 'c2 172.16.2.10/24 172.16.2.1'; do
    read -r client address gateway <<<"$spec"
    addresses="$(docker exec "$(container "$client")" ip -o -4 address show 2>/dev/null)"
    routes="$(docker exec "$(container "$client")" ip -4 route show 2>/dev/null)"
    if grep -qF "$address" <<<"$addresses" \
        && grep -qE "^default via ${gateway//./\\.} " <<<"$routes"; then
        pass "$client retains its exact address and site-local default route"
    else
        fail "$client retains its exact address and site-local default route" \
            "address or default route differs"
    fi
done
dns_processes=0
watchdog_processes=0
local_records=0
vip_holders=0
for resolver in dns1 dns2; do
    [[ "$(docker exec "$(container "$resolver")" \
        sh -c "pgrep -x dnsmasq 2>/dev/null | wc -l" 2>/dev/null)" == 1 ]] \
        && dns_processes=$((dns_processes + 1))
    [[ "$(docker exec "$(container "$resolver")" \
        sh -c "pgrep -f '[/]usr/local/bin/healthcheck.sh' 2>/dev/null | wc -l" \
        2>/dev/null)" == 1 ]] && watchdog_processes=$((watchdog_processes + 1))
    local_name="$(docker exec "$(container "$resolver")" dig +time=2 +tries=1 \
        +short @127.0.0.1 TXT whoami.lab.test 2>/dev/null | tr -d '"')"
    local_data="$(docker exec "$(container "$resolver")" dig +time=2 +tries=1 \
        +short @127.0.0.1 www.lab.test 2>/dev/null)"
    [[ "$local_name" == "$resolver" && "$local_data" == 192.0.2.80 ]] \
        && local_records=$((local_records + 1))
    docker exec "$(container "$resolver")" ip -4 address show dev lo 2>/dev/null \
        | grep -q '10\.53\.53\.53/32' && vip_holders=$((vip_holders + 1))
done
check_equals "both resolvers run exactly one dnsmasq process" "$dns_processes" "2"
check_equals "both resolvers run exactly one route-health watchdog" \
    "$watchdog_processes" "2"
check_equals "both resolvers return their exact local identity and shared data" \
    "$local_records" "2"
check_equals "both resolvers hold the exact anycast VIP /32" "$vip_holders" "2"

# 28-42: core, boundary, and export policy.
if grep -qE '^[[:space:]]+neighbor 10\.0\.12\.2 remote-as 65002$' <<<"$r1_config" \
    && grep -qE '^[[:space:]]+network 10\.0\.0\.1/32$' <<<"$r1_config" \
    && grep -qE '^[[:space:]]+network 172\.16\.1\.0/24$' <<<"$r1_config"; then
    pass "r1 retains exact preconfigured core BGP intent"
else
    fail "r1 retains exact preconfigured core BGP intent" "core neighbor or origination differs"
fi
if grep -qE '^[[:space:]]+neighbor 10\.0\.12\.1 remote-as 65001$' <<<"$r2_config" \
    && grep -qE '^[[:space:]]+network 10\.0\.0\.2/32$' <<<"$r2_config" \
    && grep -qE '^[[:space:]]+network 172\.16\.2\.0/24$' <<<"$r2_config"; then
    pass "r2 retains exact preconfigured core BGP intent"
else
    fail "r2 retains exact preconfigured core BGP intent" "core neighbor or origination differs"
fi
for spec in 'r1 10.0.12.2 65002 10.0.101.2 65101' \
            'r2 10.0.12.1 65001 10.0.102.2 65102'; do
    read -r router core_peer core_as host_peer host_as <<<"$spec"
    summary_json="$(eos "$router" 'show ip bgp summary | json')"
    if CORE_PEER="$core_peer" CORE_AS="$core_as" HOST_PEER="$host_peer" \
        HOST_AS="$host_as" json_matches "$summary_json" '
import json, os, sys
peers = json.load(sys.stdin).get("vrfs", {}).get("default", {}).get("peers", {})
expected = {os.environ["CORE_PEER"]: int(os.environ["CORE_AS"]),
            os.environ["HOST_PEER"]: int(os.environ["HOST_AS"])}
ok = set(peers) == set(expected)
for address, remote_as in expected.items():
    peer = peers.get(address, {})
    ok = ok and peer.get("peerState") == "Established"
    ok = ok and str(peer.get("asn")) == str(remote_as)
raise SystemExit(0 if ok else 1)
'; then
        pass "$router has exactly its core and host peers Established with exact ASNs"
    else
        fail "$router has exactly its core and host peers Established with exact ASNs" \
            "BGP summary JSON differs"
    fi
done
for spec in 'r1 DNS1-ONLY 10.0.0.11/32' 'r2 DNS2-ONLY 10.0.0.12/32'; do
    read -r router policy unique <<<"$spec"
    config="$(eos "$router" 'show running-config')"
    if grep -qE "^ip prefix-list $policy seq 10 permit ${unique//./\\.}$" <<<"$config" \
        && grep -qE "^ip prefix-list $policy seq 20 permit 10\\.53\\.53\\.53/32$" \
            <<<"$config" \
        && [[ "$(grep -c "^ip prefix-list $policy " <<<"$config")" == 2 ]]; then
        pass "$router native inbound prefix-list permits only both service-host /32s"
    else
        fail "$router native inbound prefix-list permits only both service-host /32s" \
            "prefix-list is absent or broader than intended"
    fi
done
for spec in 'r1 DNS1-IN DNS1-ONLY' 'r2 DNS2-IN DNS2-ONLY'; do
    read -r router route_map policy <<<"$spec"
    config="$(eos "$router" 'show running-config')"
    if grep -qE "^route-map $route_map permit 10$" <<<"$config" \
        && grep -qE "^[[:space:]]+match ip address prefix-list $policy$" <<<"$config" \
        && [[ "$(grep -c "^route-map $route_map " <<<"$config")" == 1 ]]; then
        pass "$router native inbound route-map is one exact allow sequence"
    else
        fail "$router native inbound route-map is one exact allow sequence" \
            "route-map differs"
    fi
done
for spec in 'r1 10.0.101.2 65101 DNS1-IN' 'r2 10.0.102.2 65102 DNS2-IN'; do
    read -r router peer remote_as route_map <<<"$spec"
    config="$(eos "$router" 'show running-config section router bgp')"
    if grep -qE "^[[:space:]]+neighbor ${peer//./\\.} remote-as $remote_as$" <<<"$config" \
        && grep -qE "^[[:space:]]+neighbor ${peer//./\\.} route-map $route_map in$" \
            <<<"$config"; then
        pass "$router host neighbor has exact AS and inbound policy attachment"
    else
        fail "$router host neighbor has exact AS and inbound policy attachment" \
            "neighbor or attachment differs"
    fi
done
for spec in 'dns1 DNS1-EXPORT 10.0.0.11/32 DNS1-OUT 65101 10.0.0.11 10.0.101.1 65001' \
            'dns2 DNS2-EXPORT 10.0.0.12/32 DNS2-OUT 65102 10.0.0.12 10.0.102.1 65002'; do
    read -r resolver policy unique outbound local_as router_id peer remote_as <<<"$spec"
    config="$(frr "$resolver" 'show running-config')"
    connected_map="$(awk '
        $0 == "route-map CONNECTED-TO-BGP permit 10" {capture=1}
        capture {print}
        capture && $0 == "exit" {exit}
    ' <<<"$config")"
    outbound_map="$(awk -v name="$outbound" '
        $0 == "route-map " name " permit 10" {capture=1}
        capture {print}
        capture && $0 == "exit" {exit}
    ' <<<"$config")"
    expected_connected_map="$(printf '%s\n%s\n%s' \
        'route-map CONNECTED-TO-BGP permit 10' \
        " match ip address prefix-list $policy" \
        'exit')"
    expected_outbound_map="$(printf '%s\n%s\n%s' \
        "route-map $outbound permit 10" \
        " match ip address prefix-list $policy" \
        'exit')"
    if grep -qE "^ip prefix-list $policy seq 10 permit ${unique//./\\.}$" <<<"$config" \
        && grep -qE "^ip prefix-list $policy seq 20 permit 10\\.53\\.53\\.53/32$" \
            <<<"$config" \
        && [[ "$(grep -c "^ip prefix-list $policy " <<<"$config")" == 2 ]] \
        && [[ "$(grep -c '^route-map CONNECTED-TO-BGP ' <<<"$config")" == 1 ]] \
        && [[ "$connected_map" == "$expected_connected_map" ]] \
        && [[ "$(grep -c "^route-map $outbound " <<<"$config")" == 1 ]] \
        && [[ "$outbound_map" == "$expected_outbound_map" ]] \
        && grep -qE '^[[:space:]]+redistribute connected route-map CONNECTED-TO-BGP$' \
            <<<"$config" \
        && grep -qE "^[[:space:]]+neighbor ${peer//./\\.} remote-as $remote_as$" \
            <<<"$config" \
        && grep -qE "^[[:space:]]+neighbor ${peer//./\\.} route-map $outbound out$" \
            <<<"$config" \
        && grep -qE "^router bgp $local_as$" <<<"$config" \
        && grep -qE "^[[:space:]]+bgp router-id ${router_id//./\\.}$" <<<"$config"; then
        pass "$resolver has exact router ID and doubly filtered connected export"
    else
        fail "$resolver has exact router ID and doubly filtered connected export" \
            "FRR service-host policy differs"
    fi
done
for spec in 'dns1 10.0.101.1 65001' 'dns2 10.0.102.1 65002'; do
    read -r resolver peer remote_as <<<"$spec"
    summary_json="$(frr "$resolver" 'show bgp summary json')"
    if PEER="$peer" REMOTE_AS="$remote_as" json_matches "$summary_json" '
import json, os, sys
d = json.load(sys.stdin)
peers = d.get("ipv4Unicast", {}).get("peers", {})
peer = peers.get(os.environ["PEER"], {})
ok = (set(peers) == {os.environ["PEER"]}
      and peer.get("state") == "Established"
      and peer.get("remoteAs") == int(os.environ["REMOTE_AS"]))
raise SystemExit(0 if ok else 1)
'; then
        pass "$resolver has exactly one Established host peer with exact remote AS"
    else
        fail "$resolver has exactly one Established host peer with exact remote AS" \
            "FRR summary JSON differs"
    fi
done
for spec in 'dns1 10.0.101.1 10.0.0.11/32' 'dns2 10.0.102.1 10.0.0.12/32'; do
    read -r resolver peer unique <<<"$spec"
    advertised="$(frr "$resolver" \
        "show bgp ipv4 unicast neighbors $peer advertised-routes")"
    prefixes="$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+' \
        <<<"$advertised" | sort -u)"
    expected="$(printf '%s\n%s\n' "$unique" '10.53.53.53/32' | sort)"
    check_equals "$resolver advertises exactly its unique /32 and shared VIP /32" \
        "$prefixes" "$expected"
done
leak_free=true
for router in r1 r2; do
    for prefix in 172.20.20.0/24 10.0.101.0/30 10.0.102.0/30; do
        leak_json="$(eos "$router" "show ip bgp $prefix | json")"
        json_matches "$leak_json" '
import json, sys
d = json.load(sys.stdin)
entries = d.get("vrfs", {}).get("default", {}).get("bgpRouteEntries", {})
raise SystemExit(0 if entries == {} else 1)
' || leak_free=false
    done
done
if [[ "$leak_free" == true ]]; then
    pass "management and service transit prefixes are absent from dynamic BGP"
else
    fail "management and service transit prefixes are absent from dynamic BGP" \
        "one or more forbidden connected prefixes leaked"
fi

# 43-50: closest-instance RIB/FIB and bounded client evidence.
for spec in 'r1 10.0.101.2 65101 10.0.12.2 65002_65102' \
            'r2 10.0.102.2 65102 10.0.12.1 65001_65101'; do
    read -r router local_next_hop local_path remote_next_hop remote_path <<<"$spec"
    remote_path="${remote_path//_/ }"
    rib_json="$(eos "$router" 'show ip bgp 10.53.53.53/32 | json')"
    if LOCAL_NEXT_HOP="$local_next_hop" LOCAL_PATH="$local_path" \
        REMOTE_NEXT_HOP="$remote_next_hop" REMOTE_PATH="$remote_path" \
        json_matches "$rib_json" '
import json, os, sys
d = json.load(sys.stdin)
entry = (d.get("vrfs", {}).get("default", {})
           .get("bgpRouteEntries", {}).get("10.53.53.53/32", {}))
paths = entry.get("bgpRoutePaths", [])
observed = {
    (path.get("nextHop"),
     path.get("asPathEntry", {}).get("asPath"),
     path.get("routeType", {}).get("active"))
    for path in paths
}
expected = {
    (os.environ["LOCAL_NEXT_HOP"], os.environ["LOCAL_PATH"], True),
    (os.environ["REMOTE_NEXT_HOP"], os.environ["REMOTE_PATH"], False),
}
ok = entry.get("totalPaths") == 2 and len(paths) == 2 and observed == expected
raise SystemExit(0 if ok else 1)
'; then
        pass "$router retains exact local-shorter best and remote VIP BGP paths"
    else
        fail "$router retains exact local-shorter best and remote VIP BGP paths" \
            "path count, AS path, or best path differs"
    fi
done
for spec in 'r1 10.0.101.2' 'r2 10.0.102.2'; do
    read -r router expected_next_hop <<<"$spec"
    route_json="$(eos "$router" 'show ip route 10.53.53.53/32 | json')"
    if EXPECTED_NEXT_HOP="$expected_next_hop" json_matches "$route_json" '
import json, os, sys
d = json.load(sys.stdin)
def collect(value):
    found = []
    if isinstance(value, dict):
        for key, item in value.items():
            if key == "nexthopAddr" and isinstance(item, str):
                found.append(item)
            else:
                found.extend(collect(item))
    elif isinstance(value, list):
        for item in value: found.extend(collect(item))
    return found
entry = d.get("vrfs", {}).get("default", {}).get("routes", {}).get("10.53.53.53/32", {})
raise SystemExit(0 if collect(entry) == [os.environ["EXPECTED_NEXT_HOP"]] else 1)
'; then
        pass "$router FIB installs only its exact local resolver next hop"
    else
        fail "$router FIB installs only its exact local resolver next hop" \
            "VIP forwarding next hop differs"
    fi
done
if [[ "$(whoami_from c1 10.53.53.53)" == dns1 \
    && "$(data_from c1 10.53.53.53)" == 192.0.2.80 ]]; then
    pass "c1 receives exact identity and shared data from local anycast dns1"
else
    fail "c1 receives exact identity and shared data from local anycast dns1" \
        "bounded DNS evidence differs"
fi
if [[ "$(whoami_from c2 10.53.53.53)" == dns2 \
    && "$(data_from c2 10.53.53.53)" == 192.0.2.80 ]]; then
    pass "c2 receives exact identity and shared data from local anycast dns2"
else
    fail "c2 receives exact identity and shared data from local anycast dns2" \
        "bounded DNS evidence differs"
fi
if [[ "$(whoami_from c2 10.0.0.11)" == dns1 \
    && "$(whoami_from c1 10.0.0.12)" == dns2 ]]; then
    pass "both cross-site unique instance addresses return exact identities"
else
    fail "both cross-site unique instance addresses return exact identities" \
        "one or both bounded unique-address queries failed"
fi
trace_one="$(docker exec "$(container c1)" traceroute -n -q 1 -w 1 -m 4 \
    10.53.53.53 2>/dev/null | awk '/^[[:space:]]*[0-9]+ / {print $1, $2}')"
trace_two="$(docker exec "$(container c2)" traceroute -n -q 1 -w 1 -m 4 \
    10.53.53.53 2>/dev/null | awk '/^[[:space:]]*[0-9]+ / {print $1, $2}')"
if [[ "$trace_one" == $'1 172.16.1.1\n2 10.53.53.53' \
    && "$trace_two" == $'1 172.16.2.1\n2 10.53.53.53' ]]; then
    pass "both bounded VIP traceroutes are exact two-hop local-instance paths"
else
    fail "both bounded VIP traceroutes are exact two-hop local-instance paths" \
        "observed c1='${trace_one//$'\n'/; }' c2='${trace_two//$'\n'/; }'"
fi

summary
