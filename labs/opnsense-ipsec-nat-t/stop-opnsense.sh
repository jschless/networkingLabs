#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$LAB_DIR/../../scripts/opnsense/runtime.sh"
opnsense_require_root
opnsense_stop_vm "$LAB_DIR/runtime/ipsec-hq" ipsec-hq
opnsense_stop_vm "$LAB_DIR/runtime/ipsec-branch" ipsec-branch
