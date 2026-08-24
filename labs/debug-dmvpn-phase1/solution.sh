#!/usr/bin/env bash
# Guided Debug answer helper: the supported answer is the minimal live repair.
set -euo pipefail

LAB_DIR=$(cd "$(dirname "$0")" && pwd)
exec "$LAB_DIR/repair.sh" "$@"
