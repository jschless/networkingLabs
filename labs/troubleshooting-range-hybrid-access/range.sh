#!/usr/bin/env bash
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
topology="$dir/topology.clab.yml"
health="$dir/health.sh"
scenarios="$dir/scenarios"
prefix=clab-troubleshooting-range-hybrid-access
state_root="${RANGE_HYBRID_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/troubleshooting-range-hybrid-access}"
attempts="$state_root/attempts"
active="$state_root/active-attempt"
nodes=(managed-client campus-edge wan-a wan-b cloud-edge pep origin-a origin-b dns)

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "==> $*"; }
node() { docker exec "$prefix-$1" "${@:2}"; }
health_gate() { "$health"; }

scenario_dir() {
    local path="$scenarios/$1"
    [[ -d "$path" && -f "$path/ticket.md" && -x "$path/inject.sh" && -x "$path/clear.sh" && -x "$path/verify.sh" ]] ||
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

restore_golden() {
    local name
    for name in "${nodes[@]}"; do
        node "$name" sh /opt/range/golden/reset.sh
    done
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
    for _ in $(seq 1 90); do
        health_gate >/dev/null 2>&1 && break
        sleep 1
    done
    health_gate
    note "range deployed at frozen topology version 1.0.0"
}

cmd_status() {
    docker inspect "$prefix-managed-client" >/dev/null 2>&1 || die "range is not deployed"
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
        while IFS= read -r path; do candidates+=("$(basename "$path")"); done < <(
            find "$scenarios" -mindepth 1 -maxdepth 1 -type d -name "t${tier}-*" | sort
        )
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
        node "$2" bash
        ;;
    *)
        echo "Usage: ./range.sh deploy|status|start <scenario>|start --tier <1|3>|verify|reset|destroy|shell <node>"
        ;;
esac
