#!/bin/sh
# Resolver process lifecycle shared by bootstrap and the supported scenario.
set -u

# shellcheck disable=SC2034  # consumed by scripts that source this library
VIP=10.53.53.53/32
WATCHDOG_PID_FILE=/run/anycast-watchdog.pid
WATCHDOG_LOCK_DIR=/run/anycast-watchdog.lock

watchdog_pids() {
    pgrep -f '[/]usr/local/bin/healthcheck.sh' 2>/dev/null || true
}

dns_pids() {
    pidof dnsmasq 2>/dev/null || true
}

process_count() {
    # shellcheck disable=SC2086  # process IDs must become positional fields
    set -- $1
    printf '%s\n' "$#"
}

stop_pid_list() {
    for pid in $1; do
        kill "$pid" 2>/dev/null || true
    done
    for _attempt in 1 2 3 4 5; do
        alive=false
        for pid in $1; do
            if kill -0 "$pid" 2>/dev/null; then
                alive=true
            fi
        done
        [ "$alive" = false ] && return 0
        sleep 1
    done
    for pid in $1; do
        kill -9 "$pid" 2>/dev/null || true
    done
}

stop_watchdog() {
    pids="$(watchdog_pids)"
    [ -z "$pids" ] || stop_pid_list "$pids"
    rm -f "$WATCHDOG_PID_FILE"
    rmdir "$WATCHDOG_LOCK_DIR" 2>/dev/null || true
}

start_watchdog() {
    stop_watchdog
    : > /var/log/healthcheck.log
    nohup sh /usr/local/bin/healthcheck.sh \
        >>/var/log/healthcheck.log 2>&1 &
    for _attempt in 1 2 3 4 5 6 7 8 9 10; do
        pids="$(watchdog_pids)"
        if [ "$(process_count "$pids")" -eq 1 ] \
            && [ -s "$WATCHDOG_PID_FILE" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

stop_dns() {
    pids="$(dns_pids)"
    [ -z "$pids" ] || stop_pid_list "$pids"
}

start_dns() {
    stop_dns
    dnsmasq --test >/dev/null 2>&1 || return 1
    dnsmasq || return 1
    for _attempt in 1 2 3 4 5 6 7 8 9 10; do
        pids="$(dns_pids)"
        if [ "$(process_count "$pids")" -eq 1 ] \
            && dig +time=1 +tries=1 +short @127.0.0.1 \
                TXT whoami.lab.test 2>/dev/null | grep -q '^"dns[12]"$'; then
            return 0
        fi
        sleep 1
    done
    return 1
}

wait_for_vip() {
    limit="$1"
    waited=0
    while [ "$waited" -lt "$limit" ]; do
        if ip -4 address show dev lo | grep -q '10\.53\.53\.53/32'; then
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}
