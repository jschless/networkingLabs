#!/usr/bin/env bash
# Transactionally apply, save, converge, and grade the canonical state.
set -Eeuo pipefail

case ${1:-} in
    -h|--help) echo 'Usage: labs/bfd-ospf/solution.sh'; exit 0 ;;
    '') ;;
    *) echo 'Usage: labs/bfd-ospf/solution.sh' >&2; exit 2 ;;
esac
(( $# == 0 )) || exit 2

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/bfd-ospf/lab-lib.sh
source "$lab_dir/lab-lib.sh"

backup_r1=''
backup_r2=''
backup_r3=''
state=''
rollback_armed=false
hold_pid=''

rollback_and_exit() {
    local reason=$1 requested=$2 status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ -n "$hold_pid" ]]; then
        kill "$hold_pid" 2>/dev/null || true
        wait "$hold_pid" 2>/dev/null || true
        hold_pid=
    fi
    if [[ "$rollback_armed" == true ]]; then
        bo_restore_backup r1 "$backup_r1" || status=1
        bo_restore_backup r2 "$backup_r2" || status=1
        bo_restore_backup r3 "$backup_r3" || status=1
        if (( status == 0 )) && bo_wait_state "$state" 45; then
            bo_delete_backup r1 "$backup_r1" || status=1
            bo_delete_backup r2 "$backup_r2" || status=1
            bo_delete_backup r3 "$backup_r3" || status=1
        else
            status=1
        fi
    fi
    (( status == 0 )) \
        || echo "ERROR: one or more independent rollback legs failed after $reason; retained snapshots require inspection" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

bo_require_tools
bo_require_inventory || { echo 'ERROR: deploy the exact three-node bfd-ospf topology first' >&2; exit 1; }
state=$(bo_classify_config) || {
    echo 'ERROR: router state is neither answer-free, canonical, nor the intended slow-timer fault' >&2
    echo 'Redeploy or remove unrelated configuration before applying the solution.' >&2
    exit 1
}

backup_r1=$(bo_make_backup r1)
if ! backup_r2=$(bo_make_backup r2); then
    bo_delete_backup r1 "$backup_r1" || true
    echo 'ERROR: could not protect every router configuration plane' >&2
    exit 1
fi
if ! backup_r3=$(bo_make_backup r3); then
    bo_delete_backup r1 "$backup_r1" || true
    bo_delete_backup r2 "$backup_r2" || true
    echo 'ERROR: could not protect every router configuration plane' >&2
    exit 1
fi
rollback_armed=true

bo_eos_config r1 <<'EOS'
enable
configure
interface Loopback0
   ip ospf area 0.0.0.0
interface Ethernet1
   ip ospf area 0.0.0.0
   ip ospf network point-to-point
   bfd interval 300 min-rx 300 multiplier 3
interface Ethernet2
   ip ospf area 0.0.0.0
   ip ospf network point-to-point
   bfd interval 300 min-rx 300 multiplier 3
router ospf 1
   router-id 10.0.0.1
   bfd default
end
EOS

[[ ${BFD_OSPF_SOLUTION_TEST_FAIL_AFTER_R1:-0} != 1 ]] || false

bo_eos_config r2 <<'EOS'
enable
configure
interface Loopback0
   ip ospf area 0.0.0.0
interface Ethernet1
   ip ospf area 0.0.0.0
   ip ospf network point-to-point
   bfd interval 300 min-rx 300 multiplier 3
interface Ethernet2
   ip ospf area 0.0.0.0
   ip ospf network point-to-point
   bfd interval 300 min-rx 300 multiplier 3
router ospf 1
   router-id 10.0.0.2
   bfd default
end
EOS

bo_eos_config r3 <<'EOS'
enable
configure
interface Loopback0
   ip ospf area 0.0.0.0
interface Ethernet1
   ip ospf area 0.0.0.0
   ip ospf network point-to-point
   bfd interval 300 min-rx 300 multiplier 3
interface Ethernet2
   ip ospf area 0.0.0.0
   ip ospf network point-to-point
   bfd interval 300 min-rx 300 multiplier 3
router ospf 1
   router-id 10.0.0.3
   bfd default
end
EOS

bo_write_memory r1
bo_write_memory r2
bo_write_memory r3

hold=${BFD_OSPF_SOLUTION_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo 'ERROR: test hold must be an integer' >&2; exit 2; }
if (( hold > 0 )); then
    sleep "$hold" & hold_pid=$!
    wait "$hold_pid"; hold_pid=
fi

bo_wait_state healthy 60 || {
    echo 'ERROR: exact OSPF/BFD state did not converge within the bounded wait' >&2
    exit 1
}
"$lab_dir/check.sh" >/dev/null || {
    echo 'ERROR: forwarding converged but exact grading failed' >&2
    exit 1
}

rollback_armed=false
trap - ERR EXIT INT TERM
cleanup_status=0
bo_delete_backup r1 "$backup_r1" || cleanup_status=1
bo_delete_backup r2 "$backup_r2" || cleanup_status=1
bo_delete_backup r3 "$backup_r3" || cleanup_status=1
(( cleanup_status == 0 )) || {
    echo 'ERROR: healthy state committed, but a bounded backup could not be deleted' >&2
    exit 1
}
echo "Healthy OSPF/BFD state applied from '$state', saved, and verified."
