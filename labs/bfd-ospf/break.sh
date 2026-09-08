#!/usr/bin/env bash
# Transactionally arm the intended slow-BFD-timer diagnosis fault.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/bfd-ospf/lab-lib.sh
source "$lab_dir/lab-lib.sh"

backup=''
rollback_armed=false
hold_pid=''

rollback_and_exit() {
    local reason=$1 requested=$2 status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ -n "$hold_pid" ]]; then kill "$hold_pid" 2>/dev/null || true; wait "$hold_pid" 2>/dev/null || true; fi
    if [[ "$rollback_armed" == true ]]; then
        bo_restore_backup r2 "$backup" || status=1
        if (( status == 0 )) && bo_wait_state healthy 45; then
            bo_delete_backup r2 "$backup" || status=1
        else
            status=1
        fi
    fi
    (( status == 0 )) || echo "ERROR: scenario rollback failed after $reason; retained snapshot requires inspection" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

bo_require_tools
bo_require_inventory || { echo 'ERROR: exact bfd-ospf topology is not running' >&2; exit 1; }
if bo_fault_ready; then echo 'Scenario is already armed in its exact intended state.'; exit 0; fi
bo_healthy_ready || { echo 'ERROR: reach the exact healthy state before arming the scenario' >&2; exit 1; }

backup=$(bo_make_backup r2)
rollback_armed=true
bo_eos_config r2 <<'EOS'
enable
configure
interface Ethernet1
   bfd interval 3000 min-rx 3000 multiplier 3
end
EOS
bo_write_memory r2

[[ ${BFD_OSPF_BREAK_TEST_FAIL_AFTER_CHANGE:-0} != 1 ]] || false
hold=${BFD_OSPF_BREAK_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo 'ERROR: test hold must be an integer' >&2; exit 2; }
if (( hold > 0 )); then sleep "$hold" & hold_pid=$!; wait "$hold_pid"; hold_pid=; fi

bo_wait_state fault 45 || { echo 'ERROR: intended slow-timer state did not converge within the bounded wait' >&2; exit 1; }

rollback_armed=false
trap - ERR EXIT INT TERM
bo_delete_backup r2 "$backup"
echo 'Scenario armed: reachability is healthy, but the r1-r2 BFD detection window is now 9000 ms.'
