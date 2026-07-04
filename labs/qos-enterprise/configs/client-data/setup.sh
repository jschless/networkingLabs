#!/bin/bash
# client-data/setup.sh — Data client: TCP flood, DSCP BE (DSCP 0, ToS 0x00)
#
# Best Effort (DSCP 0) is the default marking for standard data traffic
# (web browsing, file transfers, etc.). It gets no preferential treatment.
# We use TCP with no bandwidth cap to flood the link — this is the "noisy
# neighbor" that QoS is meant to protect voice and video from.

ip link set eth1 up
ip addr add 10.1.3.1/30 dev eth1
# "replace": the containerlab mgmt network already installed a default route,
# and a plain "ip route add default" fails on it (leaving the node unable to
# reach the far side).
ip route replace default via 10.1.3.2

echo "[client-data] Networking up: 10.1.3.1/30 gw 10.1.3.2"
echo "[client-data] Waiting 8s for server to be ready..."
sleep 8

# TCP (no -u flag): congestion-controlled, fills available bandwidth
# -b 0       no bandwidth limit — flood as fast as possible
# -t 3600    run for 1 hour
# -S 0x00    DSCP 0, Best Effort (default, but explicit here for clarity)
# -i 5       report every 5 seconds
# --forceflush  flush output immediately
# -P 4       4 parallel streams to saturate the link
nohup iperf3 -c 10.2.0.2 -b 0 -t 3600 -S 0x00 -P 4 -i 5 --forceflush \
    > /tmp/iperf3-data.log 2>&1 &

echo "[client-data] iperf3 started: TCP flood (4 streams) DSCP BE (ToS 0x00) -> 10.2.0.2"
echo "[client-data] Logs: tail -f /tmp/iperf3-data.log"
echo "[client-data] Stop: kill \$(pgrep iperf3)"
