#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$LAB_DIR/../../scripts/opnsense/runtime.sh"
opnsense_start_vm "$LAB_DIR" ipsec-hq 3072 2301 8544 br-public br-hq-lan
opnsense_start_vm "$LAB_DIR" ipsec-branch 3072 2302 8545 br-private-wan br-branch-lan
