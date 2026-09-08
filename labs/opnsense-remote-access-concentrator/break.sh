#!/usr/bin/env bash
# Transactionally arm an opaque contractor ownership mismatch on OPNsense.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/opnsense-remote-access-concentrator/lab-lib.sh
source "$lab_dir/lab-lib.sh"

fw_backup=
rollback_armed=false
hold_pid=

rollback_and_exit() {
    local reason=$1 requested=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    if [[ -n "$hold_pid" ]]; then
        kill "$hold_pid" 2>/dev/null || true
        wait "$hold_pid" 2>/dev/null || true
        hold_pid=
    fi
    [[ "$rollback_armed" != true ]] \
        || ra_restore_fw_backup "$fw_backup" >/dev/null || rollback_status=1
    (( rollback_status == 0 )) \
        || echo "ERROR: transactional rollback failed after $reason" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

ra_require_tools
ra_require_containers
ra_ssh_ready || { echo "ERROR: OPNsense SSH is not ready" >&2; exit 1; }
ra_public_keys_ready || { echo "ERROR: canonical client identities are unavailable" >&2; exit 1; }
developer_public=$(ra_client_public developer)
contractor_public=$(ra_client_public contractor)

# Take the rollback point before normalization so ERR/INT/TERM restores the
# exact pre-run state even when this is a repeated invocation of an armed lab.
fw_backup=$(ra_make_fw_backup)
rollback_armed=true

# Normalize a repeated invocation to exact health without creating any missing
# configuration, then re-arm exactly one ownership mismatch.
ra_php repair "$developer_public" "$contractor_public" "$lab_dir/configure.php" >/dev/null
ra_reload_wireguard >/dev/null
normalized=false
for _attempt in $(seq 1 45); do
    if "$lab_dir/check.sh" >/dev/null; then
        normalized=true
        break
    fi
    sleep 1
done
[[ "$normalized" == true ]] \
    || { echo "ERROR: exact healthy state is required before arming the scenario" >&2; exit 1; }

ra_php fault "$developer_public" "$contractor_public" "$lab_dir/configure.php" >/dev/null
ra_reload_wireguard >/dev/null
[[ ${RA_BREAK_TEST_FAIL_AFTER_MUTATION:-0} != 1 ]] || false

hold=${RA_BREAK_TEST_HOLD_SECONDS:-0}
[[ "$hold" =~ ^[0-9]+$ ]] || { echo "ERROR: test hold must be an integer" >&2; exit 2; }
if (( hold > 0 )); then
    sleep "$hold" &
    hold_pid=$!
    wait "$hold_pid"
    hold_pid=
fi

faulted=false
for _attempt in $(seq 1 20); do
    if ra_fault_ready "$developer_public" "$contractor_public"; then
        faulted=true
        break
    fi
    sleep 1
done
[[ "$faulted" == true ]] \
    || { echo "ERROR: scenario did not reach every bounded postcondition" >&2; exit 1; }

rollback_armed=false
trap - ERR EXIT INT TERM
ra_delete_fw_backup "$fw_backup" \
    || { echo "ERROR: fault is armed, but a restrictive firewall backup may remain at $fw_backup" >&2; exit 1; }
echo "Scenario armed: public underlay and the developer remain healthy while the contractor's entitled service is unavailable."
