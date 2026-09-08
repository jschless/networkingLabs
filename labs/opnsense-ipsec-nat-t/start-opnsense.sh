#!/usr/bin/env bash
# Start both external OPNsense roles and require bounded management readiness.
set -Eeuo pipefail

umask 077
LAB_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/opnsense/runtime.sh
source "$LAB_DIR/../../scripts/opnsense/runtime.sh"
# shellcheck source=labs/opnsense-ipsec-nat-t/lab-lib.sh
source "$LAB_DIR/lab-lib.sh"

started_hq=false
started_branch=false

rollback_and_exit() {
    local reason=$1 requested=$2
    trap - ERR EXIT INT TERM
    set +e
    [[ "$started_branch" != true ]] \
        || opnsense_stop_vm "$LAB_DIR/runtime/ipsec-branch" ipsec-branch
    [[ "$started_hq" != true ]] \
        || opnsense_stop_vm "$LAB_DIR/runtime/ipsec-hq" ipsec-hq
    rm -f "$LAB_DIR/runtime/ipsec-hq/overlay.qcow2" \
        "$LAB_DIR/runtime/ipsec-branch/overlay.qcow2"
    rmdir "$LAB_DIR/runtime/ipsec-hq" "$LAB_DIR/runtime/ipsec-branch" \
        "$LAB_DIR/runtime" 2>/dev/null || true
    echo "ERROR: VM startup rolled back after $reason" >&2
    (( requested != 0 )) || requested=1
    exit "$requested"
}
on_exit() { local status=$1; (( status == 0 )) || rollback_and_exit EXIT "$status"; }
trap 'rollback_and_exit ERR "$?"' ERR
trap 'on_exit "$?"' EXIT
trap 'rollback_and_exit INT 130' INT
trap 'rollback_and_exit TERM 143' TERM

opnsense_require_root
opnsense_require_host
opnsense_require_base
command -v sshpass >/dev/null 2>&1 \
    || { echo "ERROR: sshpass is required for bounded local readiness checks" >&2; exit 1; }
mkdir -p "$LAB_DIR/runtime"
chmod 700 "$LAB_DIR/runtime"

started_hq=true
opnsense_start_vm "$LAB_DIR" ipsec-hq 3072 2301 8544 br-public br-hq-lan
started_branch=true
opnsense_start_vm "$LAB_DIR" ipsec-branch 3072 2302 8545 br-private-wan br-branch-lan
chmod -R go-rwx "$LAB_DIR/runtime"

for peer in "$NATT_HQ_PORT:HQ" "$NATT_BRANCH_PORT:Branch"; do
    port=${peer%%:*}
    name=${peer#*:}
    ready=false
    for _attempt in $(seq 1 90); do
        if natt_ssh_ready "$port"; then
            ready=true
            break
        fi
        sleep 2
    done
    [[ "$ready" == true ]] \
        || { echo "ERROR: $name OPNsense did not become ready in the bounded wait" >&2; exit 1; }
done

trap - ERR EXIT INT TERM
echo "Both OPNsense VMs are ready on loopback-only management ports."
