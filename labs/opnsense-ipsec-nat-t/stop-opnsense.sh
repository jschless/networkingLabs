#!/usr/bin/env bash
# Stop both external roles and remove their exact disposable runtime artifacts.
set -uo pipefail

LAB_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/opnsense/runtime.sh
source "$LAB_DIR/../../scripts/opnsense/runtime.sh"
opnsense_require_root

status=0
opnsense_stop_vm "$LAB_DIR/runtime/ipsec-hq" ipsec-hq || status=1
opnsense_stop_vm "$LAB_DIR/runtime/ipsec-branch" ipsec-branch || status=1
rm -f "$LAB_DIR/runtime/ipsec-hq/overlay.qcow2" \
    "$LAB_DIR/runtime/ipsec-branch/overlay.qcow2" || status=1
for runtime_dir in "$LAB_DIR/runtime/ipsec-hq" \
    "$LAB_DIR/runtime/ipsec-branch" "$LAB_DIR/runtime"; do
    [[ -d "$runtime_dir" ]] || continue
    if ! rmdir "$runtime_dir"; then
        echo "ERROR: retained non-empty or unremovable runtime path: $runtime_dir" >&2
        status=1
    fi
done

if (( status != 0 )); then
    echo "ERROR: one or more exact OPNsense runtime artifacts could not be cleaned" >&2
    exit "$status"
fi
echo "Stopped both OPNsense VMs and removed their disposable runtime state."
