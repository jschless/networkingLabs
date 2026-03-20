#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root so tap interfaces can be removed." >&2
    exit 1
fi

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="$LAB_DIR/runtime"
PIDFILE="$RUNTIME_DIR/fgt1.pid"

for tap in fgt1-wan fgt1-corp fgt1-guest fgt1-dmz fgt1-db; do
    if ip link show "$tap" >/dev/null 2>&1; then
        ip link set "$tap" down || true
        ip link del "$tap" || true
    fi
done

if [[ -f "$PIDFILE" ]]; then
    pid="$(cat "$PIDFILE")"
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        for _ in $(seq 1 20); do
            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid"
        fi
    fi
    rm -f "$PIDFILE"
fi

echo "FortiGate VM stopped."
