#!/bin/sh
set -eu

interval="${GAD_PROBE_INTERVAL:-1}"
while true; do
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    a_code="$(curl -sS -o /tmp/a.body -w '%{http_code}' --connect-timeout 1 \
        --interface 10.115.30.53 http://10.115.30.10:8080/health || true)"
    b_code="$(curl -sS -o /tmp/b.body -w '%{http_code}' --connect-timeout 1 \
        --interface 10.115.40.53 http://10.115.40.10:8080/health || true)"
    a_state=DOWN
    b_state=DOWN
    [ "$a_code" = 200 ] && a_state=UP
    [ "$b_code" = 200 ] && b_state=UP

    : >/run/gslb/hosts.new
    if [ "$a_state" = UP ]; then
        printf '192.0.2.10 shop.gad.test api.gad.test near-a.gad.test\n' >>/run/gslb/hosts.new
    fi
    if [ "$b_state" = UP ]; then
        printf '198.51.100.10 shop.gad.test api.gad.test near-b.gad.test\n' >>/run/gslb/hosts.new
    fi
    if [ "$a_state" = DOWN ] && [ "$b_state" = UP ]; then
        printf '198.51.100.10 near-a.gad.test\n' >>/run/gslb/hosts.new
    fi
    if [ "$b_state" = DOWN ] && [ "$a_state" = UP ]; then
        printf '192.0.2.10 near-b.gad.test\n' >>/run/gslb/hosts.new
    fi
    mv /run/gslb/hosts.new /run/gslb/hosts
    printf '%s site_a=%s code=%s reason=%s site_b=%s code=%s reason=%s\n' \
        "$now" "$a_state" "${a_code:-000}" "$(tr '\n' ' ' </tmp/a.body 2>/dev/null || true)" \
        "$b_state" "${b_code:-000}" "$(tr '\n' ' ' </tmp/b.body 2>/dev/null || true)" \
        >>/var/log/gad/health.log
    sleep "$interval"
done
