#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
TOPO="$DIR/topology.clab.yml"; HEALTH="$DIR/health.sh"; SCENARIOS="$DIR/scenarios"
P=clab-troubleshooting-range-advanced
STATE_ROOT="${RANGE_ADV_STATE_DIR:-$HOME/.local/state/troubleshooting-range-advanced}"
ATTEMPTS="$STATE_ROOT/attempts"; ACTIVE="$STATE_ROOT/active-attempt"
routers=(core1 edge1 edge2 isp1 isp2 internet-core)
linux_nodes=(corp1 branch-client internet1)
die(){ echo "ERROR: $*" >&2; exit 1; }; note(){ echo "==> $*"; }
node(){ docker exec "$P-$1" "${@:2}"; }
scenario_dir(){ local p="$SCENARIOS/$1"; [[ -d "$p" && -x "$p/inject.sh" && -x "$p/clear.sh" ]] || die "unknown scenario '$1'"; echo "$p"; }
active_dir(){ [[ -f "$ACTIVE" ]] || die 'no active attempt'; local id; id="$(cat "$ACTIVE")"; echo "$ATTEMPTS/$id"; }
active_scenario(){ sed -n 's/^scenario=//p' "$(active_dir)/metadata.env"; }
health_gate(){ "$HEALTH"; }
restore_golden(){
  local n
  for n in "${routers[@]}"; do node "$n" /usr/lib/frr/frr-reload.py --reload /opt/range/golden/frr.conf --overwrite >/dev/null; done
  node edge1 sh /opt/range/golden/runtime-reset.sh
  node edge2 sh /opt/range/golden/runtime-reset.sh
  for n in "${linux_nodes[@]}"; do node "$n" sh /opt/range/golden/reset.sh; done
}
save_golden(){ local n; for n in "${routers[@]}"; do node "$n" vtysh -c 'write memory' >/dev/null; node "$n" sh -lc 'mkdir -p /opt/range/golden && cp /etc/frr/frr.conf /opt/range/golden/frr.conf'; done; }
open_attempt(){ local s="$1" now id path; now="$(date -u +%Y%m%dT%H%M%SZ)"; id="${now}-${s}-$RANDOM"; path="$ATTEMPTS/$id"; mkdir -p "$path/sessions"; printf 'scenario=%s\ntopology_version=2.0.0-draft\nstarted_utc=%s\n' "$s" "$now" >"$path/metadata.env"; cp "$(scenario_dir "$s")/ticket.md" "$path/ticket.md"; echo "$id" >"$ACTIVE"; echo "$path"; }
cmd_deploy(){ containerlab deploy --topo "$TOPO" --reconfigure; for _ in $(seq 1 90); do health_gate >/dev/null 2>&1 && break; sleep 1; done; health_gate; save_golden; }
cmd_status(){ containerlab inspect --topo "$TOPO"; health_gate; }
cmd_start(){ [[ ! -f "$ACTIVE" ]] || die 'an attempt is already active'; local s="$1" p a; p="$(scenario_dir "$s")"; health_gate; a="$(open_attempt "$s")"; if ! "$p/inject.sh"; then "$p/clear.sh" || true; rm -rf "$a"; rm -f "$ACTIVE"; die 'scenario injection failed'; fi; cat "$a/ticket.md"; }
cmd_verify(){ "$(scenario_dir "$(active_scenario)")/verify.sh"; }
cmd_reset(){ if [[ -f "$ACTIVE" ]]; then local s; s="$(active_scenario)"; "$(scenario_dir "$s")/clear.sh"; rm -f "$ACTIVE"; note "closed $s"; fi; restore_golden; for _ in $(seq 1 60); do health_gate >/dev/null 2>&1 && break; sleep 1; done; health_gate; }
case "${1:-help}" in
 deploy) cmd_deploy;; status) cmd_status;; start) cmd_start "${2:-}";; verify) cmd_verify;; reset) cmd_reset;;
 destroy) [[ ! -f "$ACTIVE" ]] || die 'reset active attempt first'; containerlab destroy --topo "$TOPO" --cleanup;;
 *) echo 'Usage: ./range.sh deploy|status|start <scenario>|verify|reset|destroy';;
esac
