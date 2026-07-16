#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$LAB_DIR/../../scripts/opnsense/runtime.sh"
opnsense_start_vm "$LAB_DIR" opnsense-ngfw 3072 2201 8444 \
    br-ngfw-wan br-ngfw-corp br-ngfw-guest br-ngfw-dmz br-ngfw-db
