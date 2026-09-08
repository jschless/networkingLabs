#!/usr/bin/env bash
# Read-only exact grader for the canonical healthy state.
set -u

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=../../scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
# shellcheck source=labs/bfd-ospf/lab-lib.sh
source "$REPO_ROOT/labs/bfd-ospf/lab-lib.sh"
LAB=bfd-ospf
TOPO_NAME=bfd-ospf
echo "=== Checking lab: $LAB (topology: $TOPO_NAME) ==="

assert_true() {
    local label=$1
    shift
    if "$@"; then pass "$label"; else fail "$label" 'observed state does not satisfy the lab contract'; fi
}

assert_equal() {
    local label=$1 actual=$2 expected=$3
    if [[ "$actual" == "$expected" ]]; then pass "$label"; else fail "$label" 'observed state differs from the lab contract'; fi
}

actual=$(timeout -k 5 15 docker ps --format '{{.Names}}' \
    | sed -n 's/^clab-bfd-ospf-//p' | LC_ALL=C sort)
assert_equal 'exact three-node inventory is running' "$actual" $'r1\nr2\nr3'

for node in r1 r2 r3; do
    assert_equal "$node uses the learned native image" \
        "$(timeout -k 5 15 docker inspect --format '{{.Config.Image}}' \
            "$(bo_container "$node")" 2>/dev/null)" ceos:4.35.2F
    version=$(bo_eos "$node" 'show version' || true)
    if grep -qE '4\.35\.2F(-46221466\.4352F)?' <<<"$version"; then
        pass "$node reports the required EOS release"
    else
        fail "$node reports the required EOS release" 'platform release differs from the lab contract'
    fi
done
assert_equal 'native router image platform is linux/amd64' \
    "$(timeout -k 5 15 docker image inspect --format '{{.Os}}/{{.Architecture}}' \
        ceos:4.35.2F 2>/dev/null)" linux/amd64

for node in r1 r2 r3; do
    assert_true "$node running base and task scope is exact" bo_plane_exact "$node" running healthy
    assert_true "$node saved base and task scope is exact" bo_plane_exact "$node" startup healthy
    assert_true "$node lab interfaces are operational" bo_interfaces_up "$node"
    assert_true "$node has exactly two expected Full point-to-point neighbors" bo_ospf_neighbors_exact "$node"
    assert_true "$node has only its two expected Up BFD peers" \
        test "$(bo_bfd_peer_tokens "$node" || true)" = "$(bo_expected_bfd_peers "$node")"
    assert_true "$node has exactly the expected OSPF routes and ECMP paths" bo_routes_exact "$node"
done

while read -r node peer interface; do
    assert_true "$node peer $peer has exact negotiated timers and OSPF registration" \
        bo_bfd_detail_exact "$node" "$peer" "$interface" 300 900
done <<'EOF'
r1 10.1.12.2 Ethernet1
r1 10.1.13.2 Ethernet2
r2 10.1.12.1 Ethernet1
r2 10.1.23.2 Ethernet2
r3 10.1.13.1 Ethernet2
r3 10.1.23.1 Ethernet1
EOF

while read -r from source to destination; do
    assert_true "$from loopback reaches $to loopback" bo_ping "$from" "$source" "$destination"
done <<'EOF'
r1 10.0.0.1 r2 10.0.0.2
r2 10.0.0.2 r1 10.0.0.1
r1 10.0.0.1 r3 10.0.0.3
r3 10.0.0.3 r1 10.0.0.1
r2 10.0.0.2 r3 10.0.0.3
r3 10.0.0.3 r2 10.0.0.2
EOF

summary
