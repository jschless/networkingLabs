#!/bin/sh
set -eu

i=0
while ! ip link show eth1 >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -lt 30 ] || { echo "server: eth1 unavailable" >&2; exit 1; }
    sleep 1
done

ip link set eth1 up
ip address replace 10.2.0.2/30 dev eth1
ip route replace default via 10.2.0.1 dev eth1

for comm in /proc/[0-9]*/comm; do
    [ -r "$comm" ] || continue
    [ "$(cat "$comm")" = "iperf3" ] || continue
    pid=${comm#/proc/}
    pid=${pid%/comm}
    kill "$pid" 2>/dev/null || true
done
rm -f /tmp/iperf3-5201.log /tmp/iperf3-5202.log /tmp/iperf3-5203.log

for port in 5201 5202 5203; do
    iperf3 -s -D -p "$port" --logfile "/tmp/iperf3-${port}.log"
done
