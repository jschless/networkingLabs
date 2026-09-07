#!/usr/bin/env bash
# Stop the external role and remove its exact disposable runtime artifacts.
set -uo pipefail

LAB_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/opnsense/runtime.sh
source "$LAB_DIR/../../scripts/opnsense/runtime.sh"
opnsense_require_root

status=0
opnsense_stop_vm "$LAB_DIR/runtime/remote-access-fw" remote-access-fw || status=1
rm -f "$LAB_DIR/runtime/remote-access-fw/overlay.qcow2" || status=1
for runtime_dir in "$LAB_DIR/runtime/remote-access-fw" "$LAB_DIR/runtime"; do
    [[ -d "$runtime_dir" ]] || continue
    if ! rmdir "$runtime_dir"; then
        echo "ERROR: retained non-empty or unremovable runtime path: $runtime_dir" >&2
        status=1
    fi
done
(( status == 0 )) || {
    echo "ERROR: one or more exact OPNsense runtime artifacts could not be cleaned" >&2
    exit "$status"
}
echo "Stopped OPNsense and removed its disposable runtime state."
