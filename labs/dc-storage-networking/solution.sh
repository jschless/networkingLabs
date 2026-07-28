#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
"$LAB_DIR/configure-fabric.sh"
"$LAB_DIR/login-storage.sh"
"$LAB_DIR/configure-multipath.sh"
"$LAB_DIR/configure-mtu.sh"
"$LAB_DIR/configure-qos.sh"
"$LAB_DIR/integrity.sh"
