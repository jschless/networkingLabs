#!/usr/bin/env bash
# Wait for the local EOS CLI to become usable, remove every matching LAN
# ingress DROP (including late boot-time reinsertion), then require 30 seconds
# of continuous absence before declaring data-plane readiness.
set -euo pipefail

interface=${1:?Linux-facing interface is required}
marker=${2:?readiness marker path is required}
stable_polls=0

rm -f "$marker"

# The rule can appear early and then be reinserted later in the cEOS boot.
# CLI readiness is the bounded synchronization point before removal begins.
for _attempt in $(seq 1 240); do
    if Cli -p 15 -c 'show version' >/dev/null 2>&1; then
        cli_ready=true
        break
    fi
    sleep 0.5
done

if [[ ${cli_ready:-false} != true ]]; then
    echo "ERROR: local EOS CLI did not become ready within the bounded wait" >&2
    exit 1
fi

# Allow three bounded minutes after CLI readiness for a late insertion,
# removal, and a complete 30-second stable-absence window.
for _attempt in $(seq 1 360); do
    removed=false
    while iptables -w 2 -C EOS_FORWARD -i "$interface" -j DROP 2>/dev/null; do
        if ! iptables -w 2 -D EOS_FORWARD -i "$interface" -j DROP; then
            break
        fi
        removed=true
    done

    if [[ "$removed" == true ]]; then
        stable_polls=0
    else
        stable_polls=$((stable_polls + 1))
        if (( stable_polls >= 60 )); then
            printf 'ready:%s\n' "$interface" >"$marker"
            exit 0
        fi
    fi
    sleep 0.5
done

echo "ERROR: cEOS forwarding rule did not remain absent within the bounded wait" >&2
exit 1
