#!/usr/bin/env bash
# Apply only the intended timer repair; reject unrelated configuration drift.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/bfd-ospf/lab-lib.sh
source "$lab_dir/lab-lib.sh"

backup=''
rollback_armed=false
rollback_and_exit() {
    local reason=$1 requested=$2 status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ "$rollback_armed" == true ]]; then
        bo_restore_backup r2 "$backup" || status=1
        if (( status == 0 )) && bo_wait_state fault 45; then
            bo_delete_backup r2 "$backup" || status=1
        else
            status=1
        fi
    fi
    (( status == 0 )) || echo "ERROR: repair rollback failed after $reason; retained snapshot requires inspection" >&2
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
if bo_healthy_ready; then "$lab_dir/check.sh"; echo 'Repair is already present; healthy state remains exact.'; exit 0; fi
bo_fault_ready || {
    echo 'ERROR: state is neither the exact intended fault nor the exact healthy state' >&2
    echo 'Remove unrelated drift or redeploy before using the focused repair.' >&2
    exit 1
}

backup=$(bo_make_backup r2)
rollback_armed=true
bo_eos_config r2 <<'EOS'
enable
configure
interface Ethernet1
   bfd interval 300 min-rx 300 multiplier 3
end
EOS
bo_write_memory r2

bo_wait_state healthy 45 || { echo 'ERROR: focused timer repair did not converge within the bounded wait' >&2; exit 1; }
"$lab_dir/check.sh" >/dev/null

rollback_armed=false
trap - ERR EXIT INT TERM
bo_delete_backup r2 "$backup"
echo 'Focused repair restored 300/300/3, saved it, and passed exact grading.'
