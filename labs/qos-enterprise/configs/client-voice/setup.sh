#!/bin/bash
# client-voice/setup.sh — Voice client: UDP 500kbps, DSCP EF (DSCP 46, ToS 0xb8)
#
# EF (Expedited Forwarding) is the standard DSCP marking for VoIP/voice traffic.
# It guarantees low latency and jitter. Real voice codecs (G.711, G.729) use
# ~64-128kbps; we simulate 500kbps to be visible against the 2Mbps WAN link.

ip link set eth1 up
ip addr add 10.1.1.1/30 dev eth1
# "replace": the containerlab mgmt network already installed a default route,
# and a plain "ip route add default" fails on it (leaving the node unable to
# reach the far side).
ip route replace default via 10.1.1.2

echo "[client-voice] Networking up: 10.1.1.1/30 gw 10.1.1.2"
echo "[client-voice] Waiting 8s for server to be ready..."
sleep 8

# -u         UDP (voice is always UDP — no TCP retransmits for real-time media)
# -b 500k    target 500kbps sending rate
# -t 3600    run for 1 hour (lab lifetime)
# -S 0xb8    set IP ToS byte to 0xb8 = DSCP 46 (EF)
# -i 5       report every 5 seconds
# --forceflush  flush output immediately (not line-buffered)
nohup iperf3 -c 10.2.0.2 -u -b 500k -t 3600 -S 0xb8 -i 5 --forceflush \
    > /tmp/iperf3-voice.log 2>&1 &

echo "[client-voice] iperf3 started: UDP 500kbps, DSCP EF (ToS 0xb8) -> 10.2.0.2"
echo "[client-voice] Logs: tail -f /tmp/iperf3-voice.log"
echo "[client-voice] Stop: kill \$(pgrep iperf3)"
