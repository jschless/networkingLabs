#!/usr/bin/env bash
set -euo pipefail

case "$(hostname)" in
    r2) expected_interfaces=(eth1 eth2) ;;
    r1 | r3) expected_interfaces=(eth1) ;;
    *) exit 1 ;;
esac

for _ in $(seq 1 20); do
    links_ready=true
    for interface in "${expected_interfaces[@]}"; do
        if ! ip link show dev "$interface" >/dev/null 2>&1; then
            links_ready=false
            break
        fi
    done
    "$links_ready" && break
    sleep 0.25
done

"${links_ready:-false}" || exit 1

/usr/lib/frr/frrinit.sh start >/dev/null

daemons_ready=false
for _ in $(seq 1 40); do
    if [[ -S /var/run/frr/zebra.vty &&
          -S /var/run/frr/bgpd.vty &&
          -S /var/run/frr/ospfd.vty &&
          -S /var/run/frr/staticd.vty ]] &&
       vtysh -c 'show version' >/dev/null 2>&1; then
        daemons_ready=true
        break
    fi
    sleep 0.25
done

"$daemons_ready" || exit 1
vtysh -b >/dev/null
