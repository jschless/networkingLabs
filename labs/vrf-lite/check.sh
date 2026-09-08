#!/usr/bin/env bash
# Read-only exact grader for the canonical healthy state.
set -u

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
# shellcheck source=labs/vrf-lite/lab-lib.sh
source "$REPO_ROOT/labs/vrf-lite/lab-lib.sh"
lab_init vrf-lite

assert_true() {
    local label=$1
    shift
    if "$@"; then pass "$label"; else fail "$label" 'observed state does not satisfy the lab contract'; fi
}

assert_equal() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then pass "$label"; else fail "$label" 'observed state differs from the lab contract'; fi
}

actual=$(docker ps --format '{{.Names}}' | sed -n 's/^clab-vrf-lite-//p' | LC_ALL=C sort)
assert_equal 'exact six-node inventory is running' "$actual" $'ce-a1\nce-a2\nce-b1\nce-b2\npe1\npe2'

for node in pe1 pe2; do
    assert_equal "$node uses the learned native image" \
        "$(docker inspect --format '{{.Config.Image}}' "$(vl_container "$node")" 2>/dev/null)" ceos:4.35.2F
    version=$(vl_eos "$node" 'show version' || true)
    if grep -qE '4\.35\.2F(-46221466\.4352F)?' <<<"$version"; then
        pass "$node reports the required EOS release"
    else
        fail "$node reports the required EOS release" 'platform release differs from the lab contract'
    fi
done
for node in ce-a1 ce-a2 ce-b1 ce-b2; do
    assert_equal "$node uses the incidental endpoint image" \
        "$(docker inspect --format '{{.Config.Image}}' "$(vl_container "$node")" 2>/dev/null)" ops-lab:local
done
assert_equal 'native router image platform is linux/amd64' \
    "$(docker image inspect --format '{{.Os}}/{{.Architecture}}' ceos:4.35.2F 2>/dev/null)" linux/amd64
assert_equal 'endpoint image platform is linux/amd64' \
    "$(docker image inspect --format '{{.Os}}/{{.Architecture}}' ops-lab:local 2>/dev/null)" linux/amd64

assert_true 'first RED endpoint scaffold is exact' vl_ce_scaffold_exact ce-a1 10.10.12.1/30 10.10.0.1/32 10.10.12.2
assert_true 'second RED endpoint scaffold is exact' vl_ce_scaffold_exact ce-a2 10.10.34.2/30 10.10.0.2/32 10.10.34.1
assert_true 'first BLUE endpoint scaffold is exact' vl_ce_scaffold_exact ce-b1 10.20.12.1/30 10.20.0.1/32 10.20.12.2
assert_true 'second BLUE endpoint scaffold is exact' vl_ce_scaffold_exact ce-b2 10.20.34.2/30 10.20.0.2/32 10.20.34.1

for node in pe1 pe2; do
    assert_true "$node running task scope is exact" vl_plane_exact "$node" running healthy
    assert_true "$node saved task scope is exact" vl_plane_exact "$node" startup healthy
    assert_true "$node data interfaces are operational" vl_interfaces_up "$node"
    assert_true "$node default routing context is unpolluted" vl_default_clean "$node"
done

route_index=0
while read -r node vrf prefix next_hop egress; do
    route_index=$((route_index + 1))
    assert_true "active FIB entry $route_index has exact resolution" \
        vl_route_active "$node" "$vrf" "$prefix" "$next_hop" "$egress"
done <<'EOF'
pe1 VRF-RED 10.10.0.1/32 10.10.12.1
pe1 VRF-RED 10.10.0.2/32 10.10.99.2
pe1 VRF-BLUE 10.20.0.1/32 10.20.12.1
pe1 VRF-BLUE 10.20.0.2/32 10.20.99.2
pe2 VRF-RED 10.10.0.1/32 10.10.99.1
pe2 VRF-RED 10.10.0.2/32 10.10.34.2
pe2 VRF-BLUE 10.20.0.1/32 10.20.99.1
pe2 VRF-BLUE 10.20.0.2/32 10.20.34.2
pe1 VRF-BLUE 10.10.0.1/32 10.10.12.1 VRF-RED
pe1 VRF-RED 10.20.0.1/32 10.20.12.1 VRF-BLUE
EOF

assert_true 'RED forwards site one to site two' vl_ping ce-a1 10.10.0.1 10.10.0.2
assert_true 'RED forwards site two to site one' vl_ping ce-a2 10.10.0.2 10.10.0.1
assert_true 'BLUE forwards site one to site two' vl_ping ce-b1 10.20.0.1 10.20.0.2
assert_true 'BLUE forwards site two to site one' vl_ping ce-b2 10.20.0.2 10.20.0.1
assert_true 'approved share forwards RED to BLUE' vl_ping ce-a1 10.10.0.1 10.20.0.1
assert_true 'approved share forwards BLUE to RED' vl_ping ce-b1 10.20.0.1 10.10.0.1

if ! vl_ping ce-a1 10.10.0.1 10.20.0.2; then pass 'unapproved path one remains isolated'; else fail 'unapproved path one remains isolated' 'an unapproved explicit-source path forwarded'; fi
if ! vl_ping ce-a2 10.10.0.2 10.20.0.1; then pass 'unapproved path two remains isolated'; else fail 'unapproved path two remains isolated' 'an unapproved explicit-source path forwarded'; fi
if ! vl_ping ce-a2 10.10.0.2 10.20.0.2; then pass 'unapproved path three remains isolated'; else fail 'unapproved path three remains isolated' 'an unapproved explicit-source path forwarded'; fi
if ! vl_ping ce-b1 10.20.0.1 10.10.0.2; then pass 'unapproved path four remains isolated'; else fail 'unapproved path four remains isolated' 'an unapproved explicit-source path forwarded'; fi
if ! vl_ping ce-b2 10.20.0.2 10.10.0.1; then pass 'unapproved path five remains isolated'; else fail 'unapproved path five remains isolated' 'an unapproved explicit-source path forwarded'; fi
if ! vl_ping ce-b2 10.20.0.2 10.10.0.2; then pass 'unapproved path six remains isolated'; else fail 'unapproved path six remains isolated' 'an unapproved explicit-source path forwarded'; fi

summary
