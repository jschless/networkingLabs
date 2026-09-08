#!/usr/bin/env bash
# Safely compare identical carrier-up packet loss with OSPF alone and with BFD.
set -Eeuo pipefail

case ${1:-} in
    -h|--help) echo 'Usage: labs/bfd-ospf/measure.sh'; exit 0 ;;
    '') ;;
    *) echo 'Usage: labs/bfd-ospf/measure.sh' >&2; exit 2 ;;
esac
(( $# == 0 )) || exit 2

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/bfd-ospf/lab-lib.sh
source "$lab_dir/lab-lib.sh"

rule_tag=bfd-ospf-silent-loss
rule_owned=false
backup_r1=''
backup_r2=''
backup_r3=''
rollback_armed=false
hold_pid=''
measured_ms=''

rule_present() {
    bo_node r2 iptables -C INPUT -i eth1 -m comment --comment "$rule_tag" -j DROP >/dev/null 2>&1
}

remove_owned_rule() {
    [[ "$rule_owned" == true ]] || return 0
    if rule_present; then
        bo_node r2 iptables -D INPUT -i eth1 -m comment --comment "$rule_tag" -j DROP >/dev/null 2>&1 || return 1
    fi
    rule_owned=false
}

r1_uses_r3_for_r2() {
    local route
    route=$(bo_eos r1 'show ip route 10.0.0.2/32') || return 1
    grep -qE 'via[[:space:]]+10\.1\.13\.2,[[:space:]]+Ethernet2' <<<"$route" \
        && ! grep -qE 'via[[:space:]]+10\.1\.12\.2,[[:space:]]+Ethernet1' <<<"$route"
}

no_bfd_ready() {
    local node peers
    bo_control_plane_exact && bo_all_pings || return 1
    for node in r1 r2 r3; do
        peers=$(bo_bfd_peer_tokens "$node") || return 1
        [[ -z "$peers" ]] || return 1
    done
}

wait_no_bfd_ready() {
    for _attempt in $(seq 1 60); do
        no_bfd_ready && return 0
        sleep 1
    done
    return 1
}

set_bfd_registration() {
    local action=$1 node
    for node in r1 r2 r3; do
        if [[ "$action" == enable ]]; then
            bo_eos_config "$node" <<'EOS'
enable
configure
router ospf 1
   bfd default
end
EOS
        else
            bo_eos_config "$node" <<'EOS'
enable
configure
router ospf 1
   no bfd default
end
EOS
        fi
    done
}

measure_failover() {
    local deadline_ms=$1 start_ms now_ms
    [[ "$rule_owned" == false ]] || return 1
    rule_owned=true
    start_ms=$(date +%s%3N)
    bo_node r2 iptables -I INPUT 1 -i eth1 -m comment --comment "$rule_tag" -j DROP >/dev/null

    [[ ${BFD_OSPF_MEASURE_TEST_FAIL_AFTER_RULE:-0} != 1 ]] || false
    hold=${BFD_OSPF_MEASURE_TEST_HOLD_SECONDS:-0}
    [[ "$hold" =~ ^[0-9]+$ ]] || { echo 'ERROR: test hold must be an integer' >&2; return 2; }
    if (( hold > 0 )); then sleep "$hold" & hold_pid=$!; wait "$hold_pid"; hold_pid=; fi

    while true; do
        if r1_uses_r3_for_r2; then
            now_ms=$(date +%s%3N)
            measured_ms=$((now_ms - start_ms))
            break
        fi
        now_ms=$(date +%s%3N)
        (( now_ms - start_ms < deadline_ms )) || {
            echo 'ERROR: alternate path was not selected within the bounded observation window' >&2
            return 1
        }
        sleep 0.1
    done
    bo_interfaces_up r2 || {
        echo 'ERROR: the injected test changed carrier state; result is not a BFD proof' >&2
        return 1
    }
    remove_owned_rule
}

rollback_and_exit() {
    local reason=$1 requested=$2 status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ -n "$hold_pid" ]]; then kill "$hold_pid" 2>/dev/null || true; wait "$hold_pid" 2>/dev/null || true; fi
    remove_owned_rule || status=1
    if [[ "$rollback_armed" == true ]]; then
        bo_restore_backup r1 "$backup_r1" || status=1
        bo_restore_backup r2 "$backup_r2" || status=1
        bo_restore_backup r3 "$backup_r3" || status=1
        if (( status == 0 )) && bo_wait_state healthy 60; then
            bo_delete_backup r1 "$backup_r1" || status=1
            bo_delete_backup r2 "$backup_r2" || status=1
            bo_delete_backup r3 "$backup_r3" || status=1
        else
            status=1
        fi
    fi
    (( status == 0 )) \
        || echo "ERROR: measurement rollback failed after $reason; retained snapshots require inspection" >&2
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
bo_healthy_ready || { echo 'ERROR: measurement accepts only the exact canonical healthy state' >&2; exit 1; }
rule_present && { echo 'ERROR: the owned measurement rule already exists; remove or inspect it first' >&2; exit 1; }

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

set_bfd_registration disable
[[ ${BFD_OSPF_MEASURE_TEST_FAIL_AFTER_OSPF_DISABLE:-0} != 1 ]] || false
wait_no_bfd_ready || { echo 'ERROR: OSPF-only state did not settle within the bounded wait' >&2; exit 1; }

measure_failover 60000
ospf_ms=$measured_ms
wait_no_bfd_ready || { echo 'ERROR: OSPF-only state did not reconverge after rule removal' >&2; exit 1; }

set_bfd_registration enable
bo_wait_state healthy 45 || { echo 'ERROR: BFD state did not reconverge within the bounded wait' >&2; exit 1; }

measure_failover 10000
bfd_ms=$measured_ms
bo_wait_state healthy 45 || { echo 'ERROR: healthy state did not return after BFD measurement' >&2; exit 1; }

(( ospf_ms >= 30000 && ospf_ms <= 55000 )) || {
    echo "ERROR: OSPF-only result ${ospf_ms}ms is outside the accepted 30-55s virtual-lab window" >&2
    exit 1
}
(( bfd_ms > 0 && bfd_ms < 5000 )) || {
    echo "ERROR: BFD result ${bfd_ms}ms is outside the accepted sub-5s virtual-lab window" >&2
    exit 1
}

rollback_armed=false
trap - ERR EXIT INT TERM
cleanup_status=0
bo_delete_backup r1 "$backup_r1" || cleanup_status=1
bo_delete_backup r2 "$backup_r2" || cleanup_status=1
bo_delete_backup r3 "$backup_r3" || cleanup_status=1
(( cleanup_status == 0 )) || { echo 'ERROR: verified state remains, but a bounded backup could not be deleted' >&2; exit 1; }

printf 'OSPF-only carrier-up detection: %d ms\n' "$ospf_ms"
printf 'BFD carrier-up detection: %d ms\n' "$bfd_ms"
echo 'PASS: both trials used the same owned INPUT drop, kept Ethernet1 up/up, selected the r3 alternate, and restored exact healthy state.'
