#!/bin/sh
set -eu

# shellcheck source=/dev/null
. /usr/local/bin/service-control.sh

case "${1:-}" in
    break)
        stop_watchdog
        stop_dns
        ip address replace "$VIP" dev lo
        [ -z "$(watchdog_pids)" ]
        [ -z "$(dns_pids)" ]
        ip -4 address show dev lo | grep -q '10\.53\.53\.53/32'
        ;;
    repair)
        start_dns
        start_watchdog
        wait_for_vip 15
        ;;
    *)
        echo "usage: $0 {break|repair}" >&2
        exit 2
        ;;
esac
