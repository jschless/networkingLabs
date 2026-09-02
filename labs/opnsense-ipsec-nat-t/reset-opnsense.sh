#!/usr/bin/env bash
set -euo pipefail
LAB_DIR=$(cd "$(dirname "$0")" && pwd)
[[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
"$LAB_DIR/stop-opnsense.sh"
"$LAB_DIR/start-opnsense.sh"
