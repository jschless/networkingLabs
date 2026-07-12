#!/usr/bin/env bash
# No-restart reset proof for the troubleshooting range.
#
# Uses only in-container golden copies. It must never modify a config mounted
# from this repository. `test` is intentionally self-cleaning.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TOPO="$DIR/topology.clab.yml"
LAB="tr-range-reset-prototype"
P="clab-$LAB"

die() { echo "ERROR: $*" >&2; exit 1; }
node() { docker exec "$P-$1" "${@:2}"; }
eos_show() { docker exec "$P-sw1" Cli -p 15 -c enable -c "$1"; }
eos_config() {
    # Cli's repeated -c arguments do not retain configuration-submode state.
    # Feed an actual interactive command stream instead.
    {
        printf '%s\n' enable configure
        printf '%s\n' "$@"
        printf '%s\n' end
    } | docker exec -i "$P-sw1" Cli -p 15
}
eos_access_up() { eos_show 'show interfaces Ethernet2 status' | grep -q 'connected'; }

wait_for() {
    local description="$1"; shift
    local i
    for i in $(seq 1 60); do
        "$@" >/dev/null 2>&1 && return 0
        sleep 1
    done
    die "timed out waiting for $description"
}

deploy() {
    containerlab deploy --topo "$TOPO" --reconfigure
    wait_for "cEOS CLI" eos_show "show hostname"
    wait_for "FRR config" node r1 vtysh -c 'show ip route 198.51.100.0/24'
    # cEOS accepts its CLI before the data plane is necessarily ready. The
    # direct cEOS↔FRR routed/bridged reachability is deterministic; endpoint
    # ARP timing is intentionally not part of this reset-mechanism prototype.
    wait_for "cEOS-to-FRR forwarding" eos_show "ping 192.0.2.2 repeat 1 timeout 1"
    wait_for "cEOS access port" eos_access_up
    # cEOS starts from source-controlled startup-config; create a writable,
    # in-container snapshot after the platform has reached its golden state.
    eos_show 'copy running-config flash:golden.cfg' >/dev/null
    echo "Prototype deployed; golden snapshots created inside containers."
}

destroy() {
    containerlab destroy --topo "$TOPO" --cleanup
}

baseline() {
    eos_access_up \
        || die "cEOS access port Ethernet2 is not connected"
    node r1 vtysh -c 'show ip route 198.51.100.0/24' | grep -q '198\.51\.100\.0/24' \
        || die "r1 golden static route is absent"
    node host1 ip -br address show eth1 | grep -q '192\.0\.2\.10/24' \
        || die "host1 golden address is absent"
    echo "Baseline is healthy."
}

break_state() {
    eos_config 'interface Ethernet2' 'shutdown' >/dev/null
    node r1 vtysh -c 'configure terminal' -c 'no ip route 198.51.100.0/24 Null0' -c end
    node host1 sh -c 'ip addr flush dev eth1; ip addr add 192.0.2.99/24 dev eth1; ip route replace default via 192.0.2.1'
    echo "Faults injected on cEOS, FRR, and Linux endpoint."
}

assert_broken() {
    eos_show 'show interfaces Ethernet2 status' | grep -q 'disabled' \
        || die "cEOS injected fault did not disable Ethernet2"
    if node r1 vtysh -c 'show ip route 198.51.100.0/24' | grep -q '198\.51\.100\.0/24'; then
        die "FRR injected fault did not remove static route"
    fi
    node host1 ip -br address show eth1 | grep -q '192\.0\.2\.99/24' \
        || die "Linux injected fault did not change address"
    echo "All three faults are observable."
}

reset_state() {
    # cEOS configure replace is non-interactive with the default answer on
    # cEOS 4.35.2F. It reloads configuration, not the container process.
    eos_show 'configure replace flash:golden.cfg' >/dev/null
    node r1 /usr/lib/frr/frr-reload.py --reload /opt/range/golden/frr.conf --overwrite
    node host1 sh /opt/range/golden/reset.sh
    echo "Golden state restored without a container restart."
}

started_at() {
    docker inspect --format '{{.State.StartedAt}}' "$P-$1"
}

test_reset() {
    local sw_start r1_start host_start reset_started reset_finished reset_seconds rc=0
    trap 'destroy >/dev/null 2>&1 || true' EXIT
    deploy
    baseline
    sw_start="$(started_at sw1)"
    r1_start="$(started_at r1)"
    host_start="$(started_at host1)"
    break_state
    assert_broken
    reset_started="$(date +%s)"
    reset_state
    reset_finished="$(date +%s)"
    reset_seconds=$((reset_finished - reset_started))
    wait_for "restored cEOS access port" eos_show "show interfaces Ethernet2 status"
    baseline
    [[ "$sw_start" == "$(started_at sw1)" ]] || { echo "cEOS container restarted" >&2; rc=1; }
    [[ "$r1_start" == "$(started_at r1)" ]] || { echo "FRR container restarted" >&2; rc=1; }
    [[ "$host_start" == "$(started_at host1)" ]] || { echo "Linux container restarted" >&2; rc=1; }
    [[ $rc -eq 0 ]] || die "reset restarted a container"
    echo "PASS: all golden-state resets succeeded with identical container start times (${reset_seconds}s reset)."
}

case "${1:-help}" in
    deploy) deploy ;;
    destroy) destroy ;;
    baseline) baseline ;;
    break) break_state ;;
    reset) reset_state ;;
    test) test_reset ;;
    *)
        cat <<'EOF'
Usage: ./reset.sh {deploy|destroy|baseline|break|reset|test}

test deploys the disposable three-node topology, proves cEOS/FRR/Linux reset,
asserts no container restart, and destroys it.
EOF
        ;;
esac
