#!/usr/bin/env bash
# Transactionally arm the intended inactive cross-VRF-static fault.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/vrf-lite/lab-lib.sh
source "$lab_dir/lab-lib.sh"

backup=
rollback_armed=false
hold_pid=

rollback_and_exit() {
    local reason=$1 requested=$2 status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ -n "$hold_pid" ]]; then
        kill "$hold_pid" 2>/dev/null || true
        wait "$hold_pid" 2>/dev/null || true
    fi
    if [[ "$rollback_armed" == true ]]; then
        vl_restore_backup pe1 "$backup" || status=1
        if (( status == 0 )); then
            restored=false
            for _attempt in $(seq 1 30); do
                if vl_healthy_ready; then restored=true; break; fi
                sleep 1
            done
            if [[ "$restored" == true ]]; then
                vl_delete_backup pe1 "$backup" || status=1
            else
                status=1
            fi
        fi
    fi
    (( status == 0 )) || echo "ERROR: scenario rollback failed after $reason" >&2
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
if vl_fault_ready; then
    echo 'Scenario is already armed in its exact intended state.'
    exit 0
fi
vl_healthy_ready || {
    echo 'ERROR: reach the exact healthy state before arming the scenario' >&2
    exit 1
}

backup=$(vl_make_backup pe1)
rollback_armed=true
vl_eos_config pe1 <<'EOS'
enable
configure
no ip route vrf VRF-BLUE 10.10.0.1/32 egress-vrf VRF-RED 10.10.12.1
ip route vrf VRF-BLUE 10.10.0.1/32 10.10.12.1
end
EOS
vl_write_memory pe1

[[ ${VRF_LITE_BREAK_TEST_FAIL_AFTER_MUTATION:-0} != 1 ]] || false
hold=${VRF_LITE_BREAK_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo 'ERROR: test hold must be an integer' >&2; exit 2; }
if (( hold > 0 )); then
    sleep "$hold" &
    hold_pid=$!
    wait "$hold_pid"
    hold_pid=
fi

faulted=false
for _attempt in $(seq 1 30); do
    if vl_fault_ready; then faulted=true; break; fi
    sleep 1
done
[[ "$faulted" == true ]] || {
    echo 'ERROR: scenario did not reach its bounded failure boundary' >&2
    exit 1
}

rollback_armed=false
trap - ERR EXIT INT TERM
vl_delete_backup pe1 "$backup"
echo 'Scenario armed: same-tenant paths remain healthy, but the approved share has lost return reachability.'
