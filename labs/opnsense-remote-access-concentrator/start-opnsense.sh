#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$LAB_DIR/../../scripts/opnsense/runtime.sh"
opnsense_start_vm "$LAB_DIR" remote-access-fw 3072 2401 8644 br-remote-wan br-corp
