#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TOPO="$DIR/topology.clab.yml"; HEALTH="$DIR/health.sh"; SCENARIOS="$DIR/scenarios"
P=clab-troubleshooting-range-campus
STATE_ROOT="${RANGE_CAMPUS_STATE_DIR:-$HOME/.local/state/troubleshooting-range-campus}"
ATTEMPTS="$STATE_ROOT/attempts"; ACTIVE="$STATE_ROOT/active-attempt"
switches=(dist1 acc1); linux_nodes=(campus1 voice1 dhcp1 rogue1)
die(){ echo "ERROR: $*" >&2; exit 1; }; note(){ echo "==> $*"; }
node(){ docker exec "$P-$1" "${@:2}"; }
eos(){ docker exec "$P-$1" Cli -p 15 -c enable -c "$2"; }
scenario_dir(){ local p="$SCENARIOS/$1"; [[ -d "$p" && -f "$p/ticket.md" && -x "$p/inject.sh" && -x "$p/clear.sh" ]] || die "unknown scenario '$1'"; echo "$p"; }
active_dir(){ [[ -f "$ACTIVE" ]] || die 'no active attempt'; local id; id="$(cat "$ACTIVE")"; [[ -d "$ATTEMPTS/$id" ]] || die 'active attempt directory is missing'; echo "$ATTEMPTS/$id"; }
active_scenario(){ sed -n 's/^scenario=//p' "$(active_dir)/metadata.env"; }
health_gate(){ "$HEALTH"; }
save_golden(){ local n; for n in "${switches[@]}"; do eos "$n" 'copy running-config flash:range-golden.cfg' >/dev/null; done; }
restore_golden(){ local n; for n in "${switches[@]}"; do eos "$n" 'configure replace flash:range-golden.cfg' >/dev/null; done; { printf '%s\n' enable configure 'interface Ethernet5' shutdown 'no shutdown' end; } | docker exec -i "$P-acc1" Cli -p 15 >/dev/null; for n in "${linux_nodes[@]}"; do node "$n" sh /opt/range/golden/reset.sh; done; }
open_attempt(){ local s=$1 now id path; [[ ! -f "$ACTIVE" ]] || die "an attempt is already active ($(cat "$ACTIVE"))"; now="$(date -u +%Y%m%dT%H%M%SZ)"; id="${now}-${s}-$RANDOM"; path="$ATTEMPTS/$id"; mkdir -p "$path/sessions"; printf 'attempt_id=%s\nscenario=%s\ntopology_version=3.0.0-draft\nstarted_utc=%s\n' "$id" "$s" "$now" >"$path/metadata.env"; cp "$(scenario_dir "$s")/ticket.md" "$path/ticket.md"; echo "$id" >"$ACTIVE"; echo "$path"; }
close_attempt(){ local path; path="$(active_dir)"; printf 'stopped_utc=%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" >>"$path/metadata.env"; rm -f "$ACTIVE"; note "closed attempt $(basename "$path")"; }
cmd_deploy(){ containerlab deploy --topo "$TOPO" --reconfigure; for _ in $(seq 1 90); do health_gate >/dev/null 2>&1 && break; sleep 1; done; health_gate; save_golden; note 'range deployed and golden snapshots saved'; }
cmd_status(){ docker inspect "$P-dist1" >/dev/null 2>&1 || die 'range is not deployed'; containerlab inspect --topo "$TOPO"; health_gate; }
cmd_start(){ local s=${1:-} p a; [[ -n "$s" ]] || die 'scenario or --tier is required'; if [[ "$s" == --tier ]]; then local t=${2:-} candidates=(); [[ "$t" =~ ^[123]$ ]] || die 'tier must be 1, 2, or 3'; while IFS= read -r p; do candidates+=("$(basename "$p")"); done < <(find "$SCENARIOS" -mindepth 1 -maxdepth 1 -type d -name "t${t}-*" | sort); [[ ${#candidates[@]} -gt 0 ]] || die "no tier $t scenarios are installed"; s="${candidates[RANDOM % ${#candidates[@]}]}"; fi; p="$(scenario_dir "$s")"; health_gate; a="$(open_attempt "$s")"; if ! "$p/inject.sh"; then "$p/clear.sh" || true; rm -rf "$a"; rm -f "$ACTIVE"; die 'scenario injection failed'; fi; note 'ticket started; engineer-facing ticket follows'; cat "$a/ticket.md"; }
cmd_verify(){ "$(scenario_dir "$(active_scenario)")/verify.sh"; }
cmd_reset(){ if [[ -f "$ACTIVE" ]]; then local s; s="$(active_scenario)"; note "clearing active scenario $s"; "$(scenario_dir "$s")/clear.sh"; close_attempt; fi; note 'restoring golden state without restarts'; restore_golden; for _ in $(seq 1 60); do health_gate >/dev/null 2>&1 && break; sleep 1; done; health_gate; }
case "${1:-help}" in
  deploy) cmd_deploy;; status) cmd_status;; start) shift; cmd_start "$@";; verify) cmd_verify;; reset) cmd_reset;; destroy) [[ ! -f "$ACTIVE" ]] || die 'reset active attempt first'; containerlab destroy --topo "$TOPO" --cleanup;; *) echo 'Usage: ./range.sh deploy|status|start <scenario>|verify|reset|destroy';;
esac
