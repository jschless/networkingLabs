#!/usr/bin/env bash
# Remove only the opaque NAT-boundary fault, then re-establish from saved state.
set -euo pipefail

lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/opnsense-ipsec-nat-t/lab-lib.sh
source "$lab_dir/lab-lib.sh"

natt_require_tools
natt_require_containers
natt_ssh_ready "$NATT_HQ_PORT" && natt_ssh_ready "$NATT_BRANCH_PORT" \
    || { echo "ERROR: both OPNsense VMs must be ready" >&2; exit 1; }

natt_delete_fault_rules
[[ "$(natt_fault_count)" == 0 ]] \
    || { echo "ERROR: marked boundary rules remain after repair" >&2; exit 1; }

# Reload only what already exists in saved OPNsense configuration. This cannot
# solve an unconfigured learner baseline or replace unrelated pollution.
natt_restart_ipsec
recovered=false
for _attempt in $(seq 1 45); do
    if natt_protected_ready; then
        recovered=true
        break
    fi
    sleep 1
done
[[ "$recovered" == true ]] \
    || { echo "ERROR: saved configuration did not re-establish protected traffic" >&2; exit 1; }

"$lab_dir/check.sh" || {
    echo "ERROR: boundary forwarding recovered, but exact healthy grading failed; use solution.sh only if full replacement is intended" >&2
    exit 1
}
echo "Repair removed only the marked UDP/4500 fault and restored exact health from saved state."
