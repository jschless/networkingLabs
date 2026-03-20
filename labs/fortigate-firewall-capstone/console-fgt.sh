#!/usr/bin/env bash
set -euo pipefail

SERIAL_PORT="${FGT_SERIAL_PORT:-5000}"
exec telnet 127.0.0.1 "$SERIAL_PORT"
