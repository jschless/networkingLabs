#!/bin/bash
# rpki-server setup
# Assigns the management IP on eth1 and starts the RTR server in the background.

ip addr add 10.0.3.2/30 dev eth1
ip link set eth1 up

echo "[setup] IP 10.0.3.2/30 assigned to eth1"
echo "[setup] Starting RTR server on port 3323..."

python3 /rtr_server.py &

echo "[setup] RTR server started (PID $!)"
