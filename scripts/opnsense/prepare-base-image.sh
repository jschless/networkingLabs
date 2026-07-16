#!/usr/bin/env bash
# Store a user-installed, management-ready OPNsense qcow2 at the location
# consumed by every OPNsense lab.  This never downloads or commits an image.
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/opnsense/runtime.sh"

usage() {
    echo "Usage: $0 /path/to/installed-opnsense.qcow2" >&2
    echo "See docs/platforms/opnsense.md before preparing the image." >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
[[ -f "$1" ]] || { echo "Source image does not exist: $1" >&2; exit 1; }
opnsense_require_root
mkdir -p "$(dirname "$OPNSENSE_BASE_IMAGE")"
qemu-img convert -p -O qcow2 "$1" "$OPNSENSE_BASE_IMAGE"
qemu-img info "$OPNSENSE_BASE_IMAGE"
echo "Prepared $OPNSENSE_BASE_IMAGE"
