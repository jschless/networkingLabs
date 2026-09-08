#!/usr/bin/env bash
# Guided-debug answer helper: the supported solution is the minimal live repair.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$LAB_DIR/repair.sh"
