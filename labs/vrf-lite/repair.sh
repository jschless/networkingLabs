#!/usr/bin/env bash
# Apply only the intended fault repair; reject unrelated configuration drift.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/vrf-lite/lab-lib.sh
source "$lab_dir/lab-lib.sh"

backup=
rollback_armed=false

rollback_and_exit() {
    local reason=$1 requested=$2 status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ "$rollback_armed" == true ]]; then
        vl_restore_backup pe1 "$backup" || status=1
        if (( status == 0 )); then
            restored=false
            for _attempt in $(seq 1 30); do
                if vl_fault_ready; then restored=true; break; fi
                sleep 1
            done
            if [[ "$restored" == true ]]; then
                vl_delete_backup pe1 "$backup" || status=1
            else
                status=1
            fi
        fi
    fi
    (( status == 0 )) || echo "ERROR: repair rollback failed after $reason" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

vl_require_tools
vl_require_inventory || { echo 'ERROR: exact vrf-lite topology is not running' >&2; exit 1; }
if vl_healthy_ready; then
    "$lab_dir/check.sh"
    echo 'Repair is already present; healthy state remains exact.'
    exit 0
fi
vl_fault_ready || {
    echo 'ERROR: state is neither the exact intended fault nor the exact healthy state' >&2
    echo 'Remove unrelated drift or redeploy before using the focused repair.' >&2
    exit 1
}

backup=$(vl_make_backup pe1)
rollback_armed=true
vl_eos_config pe1 <<'EOS'
enable
configure
no ip route vrf VRF-BLUE 10.10.0.1/32 10.10.12.1
ip route vrf VRF-BLUE 10.10.0.1/32 egress-vrf VRF-RED 10.10.12.1
end
EOS
vl_write_memory pe1

converged=false
for _attempt in $(seq 1 30); do
    if vl_healthy_ready; then converged=true; break; fi
    sleep 1
done
[[ "$converged" == true ]] || {
    echo 'ERROR: focused repair did not converge within the bounded wait' >&2
    exit 1
}
"$lab_dir/check.sh" >/dev/null

rollback_armed=false
trap - ERR EXIT INT TERM
vl_delete_backup pe1 "$backup"
echo 'Focused repair restored the active resolver context, saved it, and passed exact grading.'
