#!/usr/bin/env bash
# Start the external OPNsense role and require bounded management readiness.
set -Eeuo pipefail

umask 077
LAB_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/opnsense/runtime.sh
source "$LAB_DIR/../../scripts/opnsense/runtime.sh"
# shellcheck source=labs/opnsense-remote-access-concentrator/lab-lib.sh
source "$LAB_DIR/lab-lib.sh"

started=false
rollback_and_exit() {
    local reason=$1 requested=$2
    trap - ERR EXIT INT TERM
    set +e
    if [[ "$started" == true ]]; then
        opnsense_stop_vm "$LAB_DIR/runtime/remote-access-fw" remote-access-fw
        rm -f "$LAB_DIR/runtime/remote-access-fw/overlay.qcow2"
        rmdir "$LAB_DIR/runtime/remote-access-fw" "$LAB_DIR/runtime" 2>/dev/null || true
    fi
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
for tool in qemu-img qemu-system-x86_64 sshpass timeout; do
    command -v "$tool" >/dev/null 2>&1 \
        || { echo "ERROR: required host command is unavailable: $tool" >&2; exit 1; }
done
mkdir -p "$LAB_DIR/runtime"
chmod 700 "$LAB_DIR/runtime"

# From this point onward, shared startup may replace/create exact runtime
# artifacts, so this invocation owns their rollback.
started=true
opnsense_start_vm "$LAB_DIR" remote-access-fw 3072 2401 8644 br-remote-wan br-corp
chmod -R go-rwx "$LAB_DIR/runtime"

ready=false
for _attempt in $(seq 1 90); do
    if ra_ssh_ready; then
        ready=true
        break
    fi
    sleep 2
done
[[ "$ready" == true ]] \
    || { echo "ERROR: OPNsense did not become ready in the bounded wait" >&2; exit 1; }

trap - ERR EXIT INT TERM
echo "OPNsense is ready on loopback-only management ports."
