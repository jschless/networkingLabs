#!/usr/bin/env bash
# Restore only canonical contractor inner-address ownership from saved state.
set -Eeuo pipefail

umask 077
lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/opnsense-remote-access-concentrator/lab-lib.sh
source "$lab_dir/lab-lib.sh"
fw_backup=
rollback_armed=false

rollback_and_exit() {
    local reason=$1 requested=$2 rollback_status=0
    trap - ERR EXIT INT TERM
    set +e
    [[ "$rollback_armed" != true ]] \
        || ra_restore_fw_backup "$fw_backup" >/dev/null || rollback_status=1
    (( rollback_status == 0 )) \
        || echo "ERROR: focused-repair rollback failed after $reason" >&2
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

fw_backup=$(ra_make_fw_backup)
rollback_armed=true
ra_php repair "$developer_public" "$contractor_public" "$lab_dir/configure.php" >/dev/null
ra_reload_wireguard >/dev/null

recovered=false
for _attempt in $(seq 1 45); do
    if "$lab_dir/check.sh" >/dev/null; then
        recovered=true
        break
    fi
    sleep 1
done
[[ "$recovered" == true ]] \
    || { echo "ERROR: focused repair did not restore exact health" >&2; exit 1; }

rollback_armed=false
trap - ERR EXIT INT TERM
ra_delete_fw_backup "$fw_backup" \
    || { echo "ERROR: health is restored, but a restrictive firewall backup may remain at $fw_backup" >&2; exit 1; }
echo "Repair restored only the contractor's canonical inner-address ownership and exact health."
