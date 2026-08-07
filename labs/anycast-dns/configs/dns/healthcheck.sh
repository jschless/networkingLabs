#!/bin/sh
# Route-health injection watchdog. A single lock owner evaluates the local
# resolver and owns the connected anycast /32.
set -u

VIP=10.53.53.53/32
PID_FILE=/run/anycast-watchdog.pid
LOCK_DIR=/run/anycast-watchdog.lock

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi

cleanup() {
    rm -f "$PID_FILE"
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

terminate() {
    cleanup
    trap - EXIT
    exit 0
}

trap cleanup EXIT
trap terminate INT TERM
printf '%s\n' "$$" >"$PID_FILE"

while :; do
    # Exit status, not output: dig prints ";; connection timed out" on
    # STDOUT, so any output-emptiness test would always look "healthy".
    # dig exits 0 when it got an answer, 9 when no server replied.
    if dig +time=1 +tries=1 +short @127.0.0.1 TXT whoami.lab.test >/dev/null 2>&1; then
        if ! ip -4 addr show dev lo | grep -q '10\.53\.53\.53'; then
            ip addr add "$VIP" dev lo
            echo "$(date -Iseconds) healthy - VIP $VIP installed on lo"
        fi
    else
        if ip -4 addr show dev lo | grep -q '10\.53\.53\.53'; then
            ip addr del "$VIP" dev lo
            echo "$(date -Iseconds) UNHEALTHY - VIP $VIP withdrawn from lo"
        fi
    fi
    sleep 2
done
