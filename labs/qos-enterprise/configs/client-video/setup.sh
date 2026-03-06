#!/bin/bash
# client-video/setup.sh — Video client: UDP 1Mbps, DSCP AF41 (DSCP 34, ToS 0x88)
#
# AF41 (Assured Forwarding class 4, drop precedence 1) is used for video
# streaming. It gets preferential treatment over Best Effort but is lower
# priority than EF voice. The WRED qdisc on the video class provides active
# queue management, dropping packets early to avoid buffer bloat.

ip link set eth1 up
ip addr add 10.1.2.1/30 dev eth1
ip route add default via 10.1.2.2

echo "[client-video] Networking up: 10.1.2.1/30 gw 10.1.2.2"
echo "[client-video] Waiting 8s for server to be ready..."
sleep 8

# -u         UDP (video streams are also typically UDP-based)
# -b 1m      target 1Mbps (video stream — above its 600kbps guarantee to
#            test borrowing and WRED behavior under congestion)
# -t 3600    run for 1 hour
# -S 0x88    set IP ToS byte to 0x88 = DSCP 34 (AF41)
# -i 5       report every 5 seconds
# --forceflush  flush output immediately
nohup iperf3 -c 10.2.0.2 -u -b 1m -t 3600 -S 0x88 -i 5 --forceflush \
    > /tmp/iperf3-video.log 2>&1 &

echo "[client-video] iperf3 started: UDP 1Mbps, DSCP AF41 (ToS 0x88) -> 10.2.0.2"
echo "[client-video] Logs: tail -f /tmp/iperf3-video.log"
echo "[client-video] Stop: kill \$(pgrep iperf3)"
