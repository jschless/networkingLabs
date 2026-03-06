#!/bin/bash
# server/setup.sh — iperf3 server: accept all traffic from all clients

ip link set eth1 up
ip addr add 10.2.0.2/30 dev eth1
ip route add default via 10.2.0.1

echo "[server] Networking up: 10.2.0.2/30 gw 10.2.0.1"

# Start iperf3 in server mode
# -s         server mode
# -D         daemon (background)
# --forceflush  flush output immediately
nohup iperf3 -s --forceflush > /tmp/iperf3-server.log 2>&1 &

echo "[server] iperf3 server started (listening on all interfaces, port 5201)"
echo "[server] Logs: tail -f /tmp/iperf3-server.log"
echo "[server] Connections from:"
echo "           client-voice  10.1.1.1  (UDP 500kbps  DSCP EF)"
echo "           client-video  10.1.2.1  (UDP 1Mbps    DSCP AF41)"
echo "           client-data   10.1.3.1  (TCP flood    DSCP BE)"
