#!/usr/bin/env bash
# Read-only end-state assertions. A solved lab is 31/31; the supported fault
# leaves BGP and HTTP healthy while only policy, placement, and ECMP fail.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "k8s-fabric"

PREFIX="clab-${TOPO_NAME}"
K3S_IMAGE='rancher/k3s:v1.30.6-k3s1@sha256:204d4094343ed60ff60ed4b009785151c43d8f611761929aae3a1beb02fc0adf'
CONTROLLER_IMAGE='quay.io/metallb/controller:v0.14.8@sha256:93b83b39d06bbcb0aedc0eb750c9e43e3c46dc08a6f88400ed96105224d784ec'
SPEAKER_IMAGE='quay.io/metallb/speaker:v0.14.8@sha256:fd86bfc502601d6525739d411a0045e7085a4008a732be7e271c851800952142'
WEB_IMAGE='docker.io/library/nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10'
EOS_BUILD_ID='6f39e5bb-e6c7-4637-b931-ecb30d43e034'

container() {
    printf '%s-%s\n' "$PREFIX" "$1"
}

K() {
    docker exec "$(container k3s1)" kubectl "$@" 2>/dev/null
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

running=0
for node_name in tor racksw k3s1 k3s2 client; do
    [[ "$(docker inspect --format '{{.State.Running}}' \
        "$(container "$node_name")" 2>/dev/null)" == true ]] \
        && running=$((running + 1))
done
check_equals "all five expected containers are running" "$running" "5"

check_image tor ceos:4.35.2F
check_image racksw ops-lab:local
check_image k3s1 "$K3S_IMAGE"
check_image k3s2 "$K3S_IMAGE"
check_image client ops-lab:local

tor_image_id="$(docker inspect --format '{{.Image}}' "$(container tor)" \
    2>/dev/null)"
tor_arch="$(docker image inspect --format '{{.Architecture}}' \
    "$tor_image_id" 2>/dev/null)"
version_text="$(eos tor 'show version')"
version_json="$(eos tor 'show version | json')"
case "$tor_arch" in
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
            pass "tor amd64 runtime is the exact EOS 4.35.2F engineering build"
        else
            fail "tor amd64 runtime is the exact EOS 4.35.2F engineering build" \
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
            pass "tor arm64 runtime reports supported EOS 4.36.1F and ARM architecture"
        else
            fail "tor arm64 runtime reports supported EOS 4.36.1F and ARM architecture" \
                "release line or reported architecture differs"
        fi
        ;;
    *)
        fail "tor runtime uses a supported cEOS architecture" \
            "expected amd64 or arm64 image, got '${tor_arch:-<empty>}'"
        ;;
esac

for node_name in k3s1 k3s2; do
    runtime_version="$(docker exec "$(container "$node_name")" \
        k3s --version 2>/dev/null)"
    check_contains "$node_name runs k3s v1.30.6+k3s1" \
        "$runtime_version" '^k3s version v1\.30\.6\+k3s1 '
done
for node_name in racksw client; do
    alpine_version="$(docker exec "$(container "$node_name")" \
        cat /etc/alpine-release 2>/dev/null)"
    check_equals "$node_name runs the expected Alpine release" \
        "$alpine_version" "3.20.10"
done

nodes_json="$(K get nodes -o json)"
if json_matches "$nodes_json" '
import json, sys
d = json.load(sys.stdin)
items = d.get("items", [])
expected = {"k3s1": "10.1.0.11", "k3s2": "10.1.0.12"}
observed = {}
for item in items:
    ready = any(c.get("type") == "Ready" and c.get("status") == "True"
                for c in item.get("status", {}).get("conditions", []))
    addresses = {a.get("type"): a.get("address")
                 for a in item.get("status", {}).get("addresses", [])}
    if ready:
        observed[item["metadata"]["name"]] = addresses.get("InternalIP")
raise SystemExit(0 if observed == expected else 1)
'; then
    pass "exactly k3s1 and k3s2 are Ready with rack-facing InternalIPs"
else
    fail "exactly k3s1 and k3s2 are Ready with rack-facing InternalIPs" \
        "node readiness or InternalIP identity differs"
fi

controller_json="$(K -n metallb-system get pods -l component=controller -o json)"
if CONTROLLER_IMAGE="$CONTROLLER_IMAGE" json_matches "$controller_json" '
import json, os, sys
d = json.load(sys.stdin)
expected = os.environ["CONTROLLER_IMAGE"]
digest = expected.rsplit("@", 1)[1]
items = d.get("items", [])
ok = len(items) == 1
if ok:
    item = items[0]
    containers = item["spec"].get("containers", [])
    statuses = item.get("status", {}).get("containerStatuses", [])
    ok = (item.get("status", {}).get("phase") == "Running"
          and len(containers) == 1 and containers[0].get("image") == expected
          and len(statuses) == 1 and statuses[0].get("ready") is True
          and statuses[0].get("imageID", "").endswith("@" + digest))
raise SystemExit(0 if ok else 1)
'; then
    pass "MetalLB controller runs the exact pinned image digest"
else
    fail "MetalLB controller runs the exact pinned image digest" \
        "pod readiness, spec image, or runtime imageID differs"
fi

speakers_json="$(K -n metallb-system get pods -l component=speaker -o json)"
if SPEAKER_IMAGE="$SPEAKER_IMAGE" json_matches "$speakers_json" '
import json, os, sys
d = json.load(sys.stdin)
expected = os.environ["SPEAKER_IMAGE"]
digest = expected.rsplit("@", 1)[1]
items = d.get("items", [])
ok = len(items) == 2
for item in items:
    containers = item["spec"].get("containers", [])
    statuses = item.get("status", {}).get("containerStatuses", [])
    ok = ok and item.get("status", {}).get("phase") == "Running"
    ok = ok and len(containers) == 1 and containers[0].get("image") == expected
    ok = ok and len(statuses) == 1 and statuses[0].get("ready") is True
    ok = ok and statuses[0].get("imageID", "").endswith("@" + digest)
raise SystemExit(0 if ok else 1)
'; then
    pass "exactly two MetalLB speakers run the pinned image digest"
else
    fail "exactly two MetalLB speakers run the pinned image digest" \
        "speaker count, readiness, spec image, or runtime imageID differs"
fi

pool_json="$(K -n metallb-system get ipaddresspool svc-pool -o json)"
if json_matches "$pool_json" '
import json, sys
d = json.load(sys.stdin)
raise SystemExit(0 if d.get("spec", {}).get("addresses") == ["198.51.100.100/32"] else 1)
'; then
    pass "svc-pool contains only the exact service VIP /32"
else
    fail "svc-pool contains only the exact service VIP /32" \
        "IPAddressPool address set differs"
fi

peer_json="$(K -n metallb-system get bgppeer tor -o json)"
if json_matches "$peer_json" '
import json, sys
s = json.load(sys.stdin).get("spec", {})
ok = s.get("myASN") == 65001 and s.get("peerASN") == 65000 and s.get("peerAddress") == "10.1.0.1"
raise SystemExit(0 if ok else 1)
'; then
    pass "MetalLB peer has the exact ToR address and ASNs"
else
    fail "MetalLB peer has the exact ToR address and ASNs" \
        "BGPPeer fields differ"
fi

advertisement_json="$(K -n metallb-system get bgpadvertisement svc-adv -o json)"
if json_matches "$advertisement_json" '
import json, sys
s = json.load(sys.stdin).get("spec", {})
raise SystemExit(0 if s.get("ipAddressPools") == ["svc-pool"] else 1)
'; then
    pass "BGPAdvertisement selects only svc-pool"
else
    fail "BGPAdvertisement selects only svc-pool" \
        "advertisement pool selection differs"
fi

service_json="$(K get service web-lb -o json)"
if json_matches "$service_json" '
import json, sys
d = json.load(sys.stdin)
ports = d.get("spec", {}).get("ports", [])
ingress = d.get("status", {}).get("loadBalancer", {}).get("ingress", [])
ok = (d.get("spec", {}).get("type") == "LoadBalancer"
      and len(ports) == 1 and ports[0].get("port") == 80
      and [i.get("ip") for i in ingress] == ["198.51.100.100"])
raise SystemExit(0 if ok else 1)
'; then
    pass "web-lb is an HTTP LoadBalancer with exact VIP 198.51.100.100"
else
    fail "web-lb is an HTTP LoadBalancer with exact VIP 198.51.100.100" \
        "service type, port, or allocation differs"
fi

if json_matches "$service_json" '
import json, sys
d = json.load(sys.stdin)
raise SystemExit(0 if d.get("spec", {}).get("externalTrafficPolicy") == "Cluster" else 1)
'; then
    pass "web-lb externalTrafficPolicy is repaired to Cluster"
else
    fail "web-lb externalTrafficPolicy is repaired to Cluster" \
        "policy is not Cluster"
fi

web_pods_json="$(K get pods -l app=web -o json)"
if WEB_IMAGE="$WEB_IMAGE" json_matches "$web_pods_json" '
import json, os, sys
d = json.load(sys.stdin)
expected = os.environ["WEB_IMAGE"]
digest = expected.rsplit("@", 1)[1]
items = d.get("items", [])
ok = len(items) == 4
for item in items:
    containers = item["spec"].get("containers", [])
    statuses = item.get("status", {}).get("containerStatuses", [])
    ready = any(c.get("type") == "Ready" and c.get("status") == "True"
                for c in item.get("status", {}).get("conditions", []))
    ok = ok and item.get("status", {}).get("phase") == "Running" and ready
    ok = ok and len(containers) == 1 and containers[0].get("image") == expected
    ok = ok and len(statuses) == 1 and statuses[0].get("ready") is True
    ok = ok and statuses[0].get("imageID", "").endswith("@" + digest)
raise SystemExit(0 if ok else 1)
'; then
    pass "exactly four ready web replicas run the pinned nginx digest"
else
    fail "exactly four ready web replicas run the pinned nginx digest" \
        "replica count, readiness, spec image, or runtime imageID differs"
fi

if json_matches "$web_pods_json" '
import collections, json, sys
items = json.load(sys.stdin).get("items", [])
placement = collections.Counter(i.get("spec", {}).get("nodeName") for i in items)
raise SystemExit(0 if placement == {"k3s1": 2, "k3s2": 2} else 1)
'; then
    pass "web endpoints are repaired to an exact two-per-node spread"
else
    fail "web endpoints are repaired to an exact two-per-node spread" \
        "expected k3s1=2 and k3s2=2"
fi

tor_config="$(eos tor 'show running-config')"
if grep -qE '^interface Ethernet1$' <<<"$tor_config" \
    && grep -qE '^[[:space:]]+ip address 10\.1\.0\.1/24$' <<<"$tor_config" \
    && grep -qE '^interface Ethernet2$' <<<"$tor_config" \
    && grep -qE '^[[:space:]]+ip address 172\.16\.9\.1/24$' <<<"$tor_config" \
    && grep -qE '^interface Loopback0$' <<<"$tor_config" \
    && grep -qE '^[[:space:]]+ip address 10\.0\.0\.254/32$' <<<"$tor_config"; then
    pass "tor retains the exact routed baseline addresses"
else
    fail "tor retains the exact routed baseline addresses" \
        "one or more native interface addresses differ"
fi

prefix_config="$(eos tor 'show running-config section ip prefix-list')"
if grep -qE '^ip prefix-list METALLB-SERVICE-ONLY seq 10 permit 198\.51\.100\.100/32$' \
    <<<"$prefix_config" \
    && [[ "$(grep -c '^ip prefix-list METALLB-SERVICE-ONLY ' \
        <<<"$prefix_config")" == 1 ]]; then
    pass "native prefix-list permits only the exact service VIP /32"
else
    fail "native prefix-list permits only the exact service VIP /32" \
        "prefix-list is absent or broader than the pool"
fi

route_map_config="$(eos tor 'show running-config section route-map METALLB-IN')"
if grep -qE '^route-map METALLB-IN permit 10$' <<<"$route_map_config" \
    && grep -qE '^[[:space:]]+match ip address prefix-list METALLB-SERVICE-ONLY$' \
        <<<"$route_map_config" \
    && [[ "$(grep -c '^route-map METALLB-IN ' <<<"$route_map_config")" == 1 ]]; then
    pass "native METALLB-IN route-map has one allowlist sequence"
else
    fail "native METALLB-IN route-map has one allowlist sequence" \
        "route-map policy differs"
fi

bgp_config="$(eos tor 'show running-config section router bgp')"
if grep -qE '^[[:space:]]+neighbor 10\.1\.0\.11 route-map METALLB-IN in$' \
    <<<"$bgp_config" \
    && grep -qE '^[[:space:]]+neighbor 10\.1\.0\.12 route-map METALLB-IN in$' \
        <<<"$bgp_config"; then
    pass "inbound allowlist is attached to both MetalLB peers"
else
    fail "inbound allowlist is attached to both MetalLB peers" \
        "one or both inbound route-map attachments are missing"
fi
check_contains "native BGP enables four-path ECMP capacity" "$bgp_config" \
    '^[[:space:]]+maximum-paths 4 ecmp 4$'
if grep -qE '^[[:space:]]+neighbor 10\.1\.0\.11 remote-as 65001$' \
    <<<"$bgp_config" \
    && grep -qE '^[[:space:]]+neighbor 10\.1\.0\.12 remote-as 65001$' \
        <<<"$bgp_config" \
    && [[ "$(grep -cE '^[[:space:]]+neighbor 10\.1\.0\.(11|12) remote-as ' \
        <<<"$bgp_config")" == 2 ]]; then
    pass "native BGP has exactly the two expected MetalLB peers"
else
    fail "native BGP has exactly the two expected MetalLB peers" \
        "neighbor set or remote AS differs"
fi

summary_json="$(eos tor 'show ip bgp summary | json')"
if json_matches "$summary_json" '
import json, sys
d = json.load(sys.stdin)
peers = d.get("vrfs", {}).get("default", {}).get("peers", {})
expected = {"10.1.0.11", "10.1.0.12"}
ok = set(peers) == expected and all(peers[p].get("peerState") == "Established" for p in expected)
raise SystemExit(0 if ok else 1)
'; then
    pass "exactly two native EOS BGP peers are Established"
else
    fail "exactly two native EOS BGP peers are Established" \
        "BGP summary JSON differs"
fi

rib_json="$(eos tor 'show ip bgp 198.51.100.100/32 | json')"
if json_matches "$rib_json" '
import json, sys
d = json.load(sys.stdin)
def contains_key(value, wanted):
    if isinstance(value, dict):
        return wanted in value or any(contains_key(v, wanted) for v in value.values())
    if isinstance(value, list):
        return any(contains_key(v, wanted) for v in value)
    return False
raise SystemExit(0 if contains_key(d, "198.51.100.100/32") else 1)
'; then
    pass "the exact service VIP /32 is present in the native BGP RIB"
else
    fail "the exact service VIP /32 is present in the native BGP RIB" \
        "VIP prefix is absent from BGP JSON"
fi

route_json="$(eos tor 'show ip route 198.51.100.100/32 | json')"
if json_matches "$route_json" '
import json, sys
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
        for item in value:
            found.extend(collect(item))
    return found
routes = d.get("vrfs", {}).get("default", {}).get("routes", {})
entry = routes.get("198.51.100.100/32", {})
raise SystemExit(0 if sorted(collect(entry)) == ["10.1.0.11", "10.1.0.12"] else 1)
'; then
    pass "the native EOS FIB has exact ECMP next-hops .11 and .12"
else
    fail "the native EOS FIB has exact ECMP next-hops .11 and .12" \
        "FIB JSON does not contain exactly both node next-hops"
fi

http_ok=false
for _attempt in {1..10}; do
    if docker exec "$(container client)" wget -qO- --timeout=5 \
        http://198.51.100.100/ 2>/dev/null | grep -q 'Welcome to nginx'; then
        http_ok=true
        break
    fi
    sleep 1
done
if [[ "$http_ok" == true ]]; then
    pass "external client reaches nginx through the fabric VIP"
else
    fail "external client reaches nginx through the fabric VIP" \
        "ten bounded HTTP attempts failed"
fi

summary
