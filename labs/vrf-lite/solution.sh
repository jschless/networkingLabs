#!/usr/bin/env bash
# Transactionally apply, save, converge, and grade the exact healthy state.
set -Eeuo pipefail

case ${1:-} in
    -h|--help)
        echo 'Usage: labs/vrf-lite/solution.sh'
        exit 0
        ;;
    '') ;;
    *) echo 'Usage: labs/vrf-lite/solution.sh' >&2; exit 2 ;;
esac
(( $# == 0 )) || exit 2

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/vrf-lite/lab-lib.sh
source "$lab_dir/lab-lib.sh"

backup_pe1=
backup_pe2=
rollback_armed=false
hold_pid=

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
        vl_restore_backup pe1 "$backup_pe1" || status=1
        vl_restore_backup pe2 "$backup_pe2" || status=1
        if (( status == 0 )); then
            restored=false
            for _attempt in $(seq 1 30); do
                case "$state" in
                    answer-free) vl_config_exact answer-free && restored=true ;;
                    healthy) vl_healthy_ready && restored=true ;;
                    fault) vl_fault_ready && restored=true ;;
                esac
                [[ "$restored" == true ]] && break
                sleep 1
            done
            if [[ "$restored" == true ]]; then
                vl_delete_backup pe1 "$backup_pe1" || status=1
                vl_delete_backup pe2 "$backup_pe2" || status=1
            else
                status=1
            fi
        fi
    fi
    (( status == 0 )) \
        || echo "ERROR: one or more independent rollback legs failed after $reason" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

vl_require_tools
vl_require_inventory || {
    echo 'ERROR: deploy the exact six-node vrf-lite topology first' >&2
    exit 1
}
for spec in \
    'ce-a1 10.10.12.1/30 10.10.0.1/32 10.10.12.2' \
    'ce-a2 10.10.34.2/30 10.10.0.2/32 10.10.34.1' \
    'ce-b1 10.20.12.1/30 10.20.0.1/32 10.20.12.2' \
    'ce-b2 10.20.34.2/30 10.20.0.2/32 10.20.34.1'; do
    read -r node link loop gateway <<<"$spec"
    vl_ce_scaffold_exact "$node" "$link" "$loop" "$gateway" || {
        echo 'ERROR: an incidental endpoint differs from its source-controlled scaffold' >&2
        exit 1
    }
done

state=$(vl_classify_config) || {
    echo 'ERROR: PE state is neither answer-free, canonical, nor the intended exercise fault' >&2
    echo 'Redeploy or remove unrelated configuration before applying the solution.' >&2
    exit 1
}

# Both running and startup planes on both PEs are protected before mutation.
backup_pe1=$(vl_make_backup pe1)
if ! backup_pe2=$(vl_make_backup pe2); then
    vl_delete_backup pe1 "$backup_pe1" || true
    echo 'ERROR: could not protect both PE configuration planes' >&2
    exit 1
fi
rollback_armed=true

vl_eos_config pe1 <<'EOS'
enable
configure
vrf instance VRF-RED
vrf instance VRF-BLUE
ip routing vrf VRF-RED
ip routing vrf VRF-BLUE
interface Ethernet1
   no switchport
   vrf VRF-RED
   ip address 10.10.12.2/30
   no shutdown
interface Ethernet2
   no switchport
   vrf VRF-RED
   ip address 10.10.99.1/30
   no shutdown
interface Ethernet3
   no switchport
   vrf VRF-BLUE
   ip address 10.20.12.2/30
   no shutdown
interface Ethernet4
   no switchport
   vrf VRF-BLUE
   ip address 10.20.99.1/30
   no shutdown
ip route vrf VRF-RED 10.10.0.1/32 10.10.12.1
ip route vrf VRF-RED 10.10.0.2/32 10.10.99.2
ip route vrf VRF-BLUE 10.20.0.1/32 10.20.12.1
ip route vrf VRF-BLUE 10.20.0.2/32 10.20.99.2
no ip route vrf VRF-BLUE 10.10.0.1/32 10.10.12.1
ip route vrf VRF-BLUE 10.10.0.1/32 egress-vrf VRF-RED 10.10.12.1
ip route vrf VRF-RED 10.20.0.1/32 egress-vrf VRF-BLUE 10.20.12.1
end
EOS

[[ ${VRF_LITE_SOLUTION_TEST_FAIL_AFTER_PE1:-0} != 1 ]] || false

vl_eos_config pe2 <<'EOS'
enable
configure
vrf instance VRF-RED
vrf instance VRF-BLUE
ip routing vrf VRF-RED
ip routing vrf VRF-BLUE
interface Ethernet1
   no switchport
   vrf VRF-RED
   ip address 10.10.99.2/30
   no shutdown
interface Ethernet2
   no switchport
   vrf VRF-RED
   ip address 10.10.34.1/30
   no shutdown
interface Ethernet3
   no switchport
   vrf VRF-BLUE
   ip address 10.20.99.2/30
   no shutdown
interface Ethernet4
   no switchport
   vrf VRF-BLUE
   ip address 10.20.34.1/30
   no shutdown
ip route vrf VRF-RED 10.10.0.1/32 10.10.99.1
ip route vrf VRF-RED 10.10.0.2/32 10.10.34.2
ip route vrf VRF-BLUE 10.20.0.1/32 10.20.99.1
ip route vrf VRF-BLUE 10.20.0.2/32 10.20.34.2
end
EOS

vl_write_memory pe1
vl_write_memory pe2

hold=${VRF_LITE_SOLUTION_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo 'ERROR: test hold must be an integer' >&2; exit 2; }
if (( hold > 0 )); then
    sleep "$hold" &
    hold_pid=$!
    wait "$hold_pid"
    hold_pid=
fi

converged=false
for _attempt in $(seq 1 45); do
    if vl_healthy_ready; then converged=true; break; fi
    sleep 1
done
[[ "$converged" == true ]] || {
    echo 'ERROR: exact VRF forwarding state did not converge within the bounded wait' >&2
    exit 1
}

"$lab_dir/check.sh" >/dev/null || {
    echo 'ERROR: forwarding converged but exact grading failed' >&2
    exit 1
}

rollback_armed=false
trap - ERR EXIT INT TERM
cleanup_status=0
vl_delete_backup pe1 "$backup_pe1" || cleanup_status=1
vl_delete_backup pe2 "$backup_pe2" || cleanup_status=1
(( cleanup_status == 0 )) || {
    echo 'ERROR: healthy state committed, but a bounded backup could not be deleted' >&2
    exit 1
}
echo "Healthy VRF-Lite state applied from '$state', saved, and verified."
