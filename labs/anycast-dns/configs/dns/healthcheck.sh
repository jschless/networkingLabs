#!/bin/sh
# Route health injection watchdog.
#
# Holds the anycast VIP on lo only while the local dnsmasq answers a real
# query. FRR redistributes connected routes (your Task 3 config), so the
# /32 enters and leaves BGP together with the service — no VIP on lo,
# no route in the network. Poll interval 2s; a dead resolver is withdrawn
# from the whole network in a few seconds.
#
# Runs in the background from /setup.sh; log: /var/log/healthcheck.log.
# Task 6 kills this script on purpose — restart it the same way setup.sh
# started it.

VIP=10.53.53.53/32

while :; do
    # Exit status, not output: dig prints ";; connection timed out" on
    # STDOUT, so any output-emptiness test would always look "healthy".
    # dig exits 0 when it got an answer, 9 when no server replied.
    if dig +time=1 +tries=1 +short @127.0.0.1 TXT whoami.lab.test >/dev/null 2>&1; then
        if ! ip -4 addr show dev lo | grep -q '10\.53\.53\.53'; then
            ip addr add "$VIP" dev lo
            echo "$(date -Iseconds) healthy — VIP $VIP installed on lo"
        fi
    else
        if ip -4 addr show dev lo | grep -q '10\.53\.53\.53'; then
            ip addr del "$VIP" dev lo
            echo "$(date -Iseconds) UNHEALTHY — VIP $VIP withdrawn from lo"
        fi
    fi
    sleep 2
done
