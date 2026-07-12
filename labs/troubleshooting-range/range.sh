#!/usr/bin/env bash
# Proctor control plane for the persistent troubleshooting range.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TOPO="$DIR/topology.clab.yml"
HEALTH="$DIR/health.sh"
SCENARIOS="$DIR/scenarios"
P="clab-troubleshooting-range"
STATE_ROOT="${RANGE_STATE_DIR:-$HOME/.local/state/troubleshooting-range}"
ATTEMPTS="$STATE_ROOT/attempts"
ACTIVE="$STATE_ROOT/active-attempt"

die() { echo "ERROR: $*" >&2; exit 1; }
note() { printf '==> %s\n' "$*"; }
node() { docker exec "$P-$1" "${@:2}"; }
eos() { docker exec "$P-$1" Cli -p 15 -c enable -c "$2"; }
is_eos() { [[ "$1" == acc1 || "$1" == acc2 ]]; }
is_frr() { [[ "$1" == core1 || "$1" == core2 || "$1" == edge || "$1" == branch1 ]]; }
range_nodes=(acc1 acc2 core1 core2 edge branch1 services1 corp1 voice1 guest1 branch-client internet1)
linux_nodes=(services1 corp1 voice1 guest1 branch-client internet1)
frr_nodes=(core1 core2 edge branch1)

usage() {
    cat <<'EOF'
Usage:
  ./range.sh deploy|destroy|status|verify|reset
  ./range.sh start <scenario> | --tier <1|2|3>
  ./range.sh attempt {open <scenario>|close|show}
  ./range.sh shell <node>

`start` first proves golden health, draws/injects a ticket, creates an attempt,
and prints only ticket.md. `shell` records a script(1) transcript in that
attempt. `reset` clears the active fault, restores all golden state in place,
and requires the health gate to pass.
EOF
}

require_deployed() { docker inspect "$P-core1" >/dev/null 2>&1 || die "range is not deployed"; }
scenario_dir() {
    local scenario="$1" path="$SCENARIOS/$scenario"
    [[ -d "$path" && -f "$path/ticket.md" && -x "$path/inject.sh" && -x "$path/clear.sh" ]] \
        || die "unknown or incomplete scenario '$scenario'"
    printf '%s\n' "$path"
}
active_dir() {
    [[ -f "$ACTIVE" ]] || die "no active attempt"
    local id
    id="$(<"$ACTIVE")"
    [[ -d "$ATTEMPTS/$id" ]] || die "active attempt directory is missing"
    printf '%s\n' "$ATTEMPTS/$id"
}
active_scenario() { sed -n 's/^scenario=//p' "$(active_dir)/metadata.env"; }
health_gate() { "$HEALTH"; }

save_golden() {
    local n
    note "saving writable in-container golden snapshots"
    for n in acc1 acc2; do eos "$n" 'copy running-config flash:range-golden.cfg' >/dev/null; done
    for n in "${frr_nodes[@]}"; do
        node "$n" sh -lc 'mkdir -p /opt/range/golden && cp /etc/frr/frr.conf /opt/range/golden/frr.conf'
    done
}

restore_golden() {
    local n
    for n in acc1 acc2; do eos "$n" 'configure replace flash:range-golden.cfg' >/dev/null; done
    for n in "${frr_nodes[@]}"; do
        node "$n" /usr/lib/frr/frr-reload.py --reload /opt/range/golden/frr.conf --overwrite >/dev/null
    done
    for n in "${linux_nodes[@]}"; do node "$n" sh /opt/range/golden/reset.sh; done
}

open_attempt() {
    local scenario="$1" id now path
    [[ ! -f "$ACTIVE" ]] || die "an attempt is already active ($(cat "$ACTIVE"))"
    scenario_dir "$scenario" >/dev/null
    now="$(date -u +%Y%m%dT%H%M%SZ)"
    id="${now}-${scenario}-$RANDOM"
    path="$ATTEMPTS/$id"
    mkdir -p "$path/sessions"
    {
        printf 'attempt_id=%s\n' "$id"
        printf 'scenario=%s\n' "$scenario"
        printf 'topology_version=1.0.0-draft\n'
        printf 'started_utc=%s\n' "$now"
    } >"$path/metadata.env"
    cp "$(scenario_dir "$scenario")/ticket.md" "$path/ticket.md"
    printf '%s\n' "$id" >"$ACTIVE"
    printf '%s\n' "$path"
}

close_attempt() {
    local path now
    path="$(active_dir)"
    now="$(date -u +%Y%m%dT%H%M%SZ)"
    printf 'stopped_utc=%s\n' "$now" >>"$path/metadata.env"
    rm -f "$ACTIVE"
    note "closed attempt $(basename "$path")"
}

cmd_deploy() {
    containerlab deploy --topo "$TOPO" --reconfigure
    local i
    for i in $(seq 1 60); do health_gate >/dev/null 2>&1 && break; sleep 1; done
    health_gate
    save_golden
    note "range deployed and golden snapshots saved"
}
cmd_destroy() {
    [[ ! -f "$ACTIVE" ]] || die "close/reset the active attempt before destroying the range"
    containerlab destroy --topo "$TOPO" --cleanup
}
cmd_status() { require_deployed; containerlab inspect --topo "$TOPO"; health_gate; }
cmd_verify() {
    require_deployed
    local scenario
    scenario="$(active_scenario)"
    "$(scenario_dir "$scenario")/verify.sh"
}
cmd_reset() {
    require_deployed
    if [[ -f "$ACTIVE" ]]; then
        local scenario
        scenario="$(active_scenario)"
        note "clearing active scenario $scenario"
        "$(scenario_dir "$scenario")/clear.sh"
        close_attempt
    fi
    note "restoring all node golden state without restarts"
    restore_golden
    local i
    for i in $(seq 1 30); do health_gate >/dev/null 2>&1 && break; sleep 1; done
    health_gate
}
cmd_start() {
    require_deployed
    local scenario="${1:-}" path attempt
    [[ -n "$scenario" ]] || die "scenario or --tier is required"
    if [[ "$scenario" == --tier ]]; then
        local tier="${2:-}" candidates=()
        [[ "$tier" =~ ^[123]$ ]] || die "tier must be 1, 2, or 3"
        while IFS= read -r path; do candidates+=("$(basename "$path")"); done < <(find "$SCENARIOS" -mindepth 1 -maxdepth 1 -type d -name "t${tier}-*" | sort)
        [[ ${#candidates[@]} -gt 0 ]] || die "no tier $tier scenarios are installed"
        scenario="${candidates[RANDOM % ${#candidates[@]}]}"
    fi
    path="$(scenario_dir "$scenario")"
    health_gate
    attempt="$(open_attempt "$scenario")"
    if ! "$path/inject.sh"; then rm -rf "$attempt"; rm -f "$ACTIVE"; die "scenario injection failed"; fi
    note "ticket started; engineer-facing ticket follows"
    cat "$attempt/ticket.md"
}
cmd_shell() {
    require_deployed
    local n="${1:-}" attempt command
    [[ " ${range_nodes[*]} " == *" $n "* ]] || die "unknown range node '$n'"
    attempt="$(active_dir)"
    if is_eos "$n"; then command=(docker exec -it "$P-$n" Cli)
    else command=(docker exec -it "$P-$n" bash); fi
    "$DIR/prototypes/transcript/capture.sh" "$attempt" "$n" -- "${command[@]}"
}

case "${1:-help}" in
    deploy) cmd_deploy ;;
    destroy) cmd_destroy ;;
    status) cmd_status ;;
    verify) cmd_verify ;;
    reset) cmd_reset ;;
    start) shift; cmd_start "$@" ;;
    shell) cmd_shell "${2:-}" ;;
    attempt)
        case "${2:-}" in
            open) open_attempt "${3:-}" ;;
            close) close_attempt ;;
            show) active_dir; cat "$(active_dir)/metadata.env" ;;
            *) usage; exit 2 ;;
        esac ;;
    help|-h|--help) usage ;;
    *) usage; exit 2 ;;
esac
