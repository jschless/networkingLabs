#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
sudo "$LAB_DIR/stop-opnsense.sh"
sudo "$LAB_DIR/start-opnsense.sh"
