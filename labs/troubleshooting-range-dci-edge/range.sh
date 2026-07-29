#!/usr/bin/env bash
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
topology="$dir/topology.clab.yml"
health="$dir/health.sh"
scenarios="$dir/scenarios"
prefix=clab-troubleshooting-range-dci-edge
state_root="${RANGE_DCI_EDGE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/troubleshooting-range-dci-edge}"
attempts="$state_root/attempts"
active="$state_root/active-attempt"
eos_nodes=(a-leaf a-bgw b-bgw b-leaf peer)
ops_nodes=(
    a-prod b-prod shared-app edge-client
    internet-client inspection public-origin
    storage-init storage-path-a storage-path-b storage-target
)
carrier_nodes=(carrier-test-a carrier-nid-a carrier-core carrier-nid-b carrier-test-b)
linux_nodes=("${ops_nodes[@]}" "${carrier_nodes[@]}")
all_nodes=("${eos_nodes[@]}" "${linux_nodes[@]}")

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "==> $*"; }
node() { docker exec "$prefix-$1" "${@:2}"; }
eos() { docker exec "$prefix-$1" Cli -p 15 -c "$2"; }
health_gate() { "$health"; }

scenario_dir() {
    local path="$scenarios/$1"
    [[ -d "$path" && -f "$path/ticket.md" && -f "$path/rubric.md" &&
       -x "$path/inject.sh" && -x "$path/clear.sh" && -x "$path/verify.sh" ]] ||
        die "unknown scenario '$1'"
    echo "$path"
}

active_dir() {
    [[ -f "$active" ]] || die "no active attempt"
    local id
    id="$(cat "$active")"
    [[ -d "$attempts/$id" ]] || die "active attempt directory is missing"
    echo "$attempts/$id"
}

active_scenario() {
    sed -n 's/^scenario=//p' "$(active_dir)/metadata.env"
}

save_golden() {
    local name
    for name in "${eos_nodes[@]}"; do
        eos "$name" $'enable\ncopy running-config flash:range-golden.cfg' >/dev/null
    done
}

restore_golden() {
    local name pid pids=()
    for name in "${eos_nodes[@]}"; do
        eos "$name" $'enable\nconfigure replace flash:range-golden.cfg' >/dev/null &
        pids+=("$!")
    done
    for name in "${ops_nodes[@]}"; do
        node "$name" sh /opt/range/golden/reset.sh &
        pids+=("$!")
    done
    for name in "${carrier_nodes[@]}"; do
        node "$name" bash /opt/range/golden/reset.sh &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do wait "$pid"; done
    eos a-bgw $'enable\nclear bgp * soft in\nclear bgp * soft out' >/dev/null &
    pids=("$!")
    eos b-bgw $'enable\nclear bgp * soft in\nclear bgp * soft out' >/dev/null &
    pids+=("$!")
    for pid in "${pids[@]}"; do wait "$pid"; done
}

open_attempt() {
    local scenario=$1 now id path
    now="$(date -u +%Y%m%dT%H%M%SZ)"
    id="${now}-${scenario}-${RANDOM}"
    path="$attempts/$id"
    mkdir -p "$path/sessions"
    {
        printf 'attempt_id=%s\n' "$id"
        printf 'scenario=%s\n' "$scenario"
        printf 'topology_version=1.0.0\n'
        printf 'started_utc=%s\n' "$now"
    } >"$path/metadata.env"
    cp "$(scenario_dir "$scenario")/ticket.md" "$path/ticket.md"
    echo "$id" >"$active"
    echo "$path"
}

close_attempt() {
    local path
    path="$(active_dir)"
    printf 'stopped_utc=%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" >>"$path/metadata.env"
    rm -f "$active"
    note "closed attempt $(basename "$path")"
}

cmd_deploy() {
    containerlab deploy --topo "$topology" --reconfigure
    for _ in $(seq 1 120); do
        health_gate >/dev/null 2>&1 && break
        sleep 1
    done
    health_gate
    save_golden
    note "range deployed at frozen topology version 1.0.0"
}

cmd_status() {
    docker inspect "$prefix-a-leaf" >/dev/null 2>&1 || die "range is not deployed"
    containerlab inspect --topo "$topology"
    health_gate
}

cmd_start() {
    local scenario=${1:-} path attempt candidates=()
    [[ -n "$scenario" ]] || die "scenario or --tier is required"
    [[ ! -f "$active" ]] || die "an attempt is already active ($(cat "$active"))"
    if [[ "$scenario" == "--tier" ]]; then
        local tier=${2:-}
        [[ "$tier" =~ ^[13]$ ]] || die "installed reference tiers are 1 and 3"
        while IFS= read -r path; do
            candidates+=("$(basename "$path")")
        done < <(find "$scenarios" -mindepth 1 -maxdepth 1 -type d -name "t${tier}-*" | sort)
        [[ ${#candidates[@]} -gt 0 ]] || die "no tier $tier scenario is installed"
        scenario="${candidates[RANDOM % ${#candidates[@]}]}"
    fi
    path="$(scenario_dir "$scenario")"
    health_gate
    attempt="$(open_attempt "$scenario")"
    if ! "$path/inject.sh"; then
        "$path/clear.sh" || true
        rm -f "$active"
        rm -rf "$attempt"
        die "scenario injection failed"
    fi
    note "ticket started; engineer-facing ticket follows"
    cat "$attempt/ticket.md"
}

cmd_verify() {
    "$(scenario_dir "$(active_scenario)")/verify.sh"
}

cmd_reset() {
    if [[ -f "$active" ]]; then
        local scenario
        scenario="$(active_scenario)"
        note "clearing active scenario $scenario"
        "$(scenario_dir "$scenario")/clear.sh"
        close_attempt
    fi
    note "restoring source-controlled golden runtime state without container restarts"
    restore_golden
    for _ in $(seq 1 60); do
        health_gate >/dev/null 2>&1 && break
        sleep 1
    done
    health_gate
}

cmd_destroy() {
    [[ ! -f "$active" ]] || die "reset the active attempt before destroy"
    containerlab destroy --topo "$topology" --cleanup
}

case "${1:-help}" in
    deploy) cmd_deploy ;;
    status) cmd_status ;;
    start) shift; cmd_start "$@" ;;
    verify) cmd_verify ;;
    reset) cmd_reset ;;
    destroy) cmd_destroy ;;
    shell)
        [[ -n "${2:-}" ]] || die "node name is required"
        [[ " ${all_nodes[*]} " == *" $2 "* ]] || die "unknown node '$2'"
        if [[ " ${eos_nodes[*]} " == *" $2 "* ]]; then
            node "$2" Cli
        else
            node "$2" bash
        fi
        ;;
    *)
        echo "Usage: ./range.sh deploy|status|start <scenario>|start --tier <1|3>|verify|reset|destroy|shell <node>"
        ;;
esac
