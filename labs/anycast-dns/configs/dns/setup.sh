#!/bin/bash
# Bounded, repeatable bootstrap for either resolver host.
set -euo pipefail

fail() {
    echo "[setup] ERROR: $*" >&2
    ip -brief address >&2 || true
    vtysh -c 'show running-config' >&2 || true
    tail -n 40 /var/log/healthcheck.log >&2 || true
    exit 1
}

for _attempt in {1..60}; do
    ip link show eth1 >/dev/null 2>&1 && break
    sleep 1
done
ip link show eth1 >/dev/null 2>&1 || fail "eth1 did not appear within 60 seconds"

config_applied=false
for _attempt in {1..90}; do
    if vtysh -b >/dev/null 2>&1; then
        config_applied=true
        break
    fi
    sleep 1
done
[ "$config_applied" = true ] \
    || fail "FRR did not accept the baseline configuration within 90 seconds"
vtysh -c 'show version' >/dev/null 2>&1 \
    || fail "FRR became unavailable after applying the baseline configuration"

# shellcheck source=/dev/null
. /usr/local/bin/service-control.sh
start_dns || fail "dnsmasq did not become uniquely ready"
start_watchdog || fail "route-health watchdog did not become uniquely ready"
wait_for_vip 15 || fail "healthy local DNS did not install the service VIP"

echo "[setup] ready"
