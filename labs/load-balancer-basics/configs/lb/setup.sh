#!/bin/bash
# lb — the load balancer (HAProxy installed, NOT running)
#
# IP:  172.16.0.10/24 (eth1, DMZ)
# GW:  172.16.0.1     (edge)
#
# /etc/haproxy is bind-mounted from labs/load-balancer-basics/haproxy/ on
# the host — edit haproxy.cfg there with your normal editor. Starting (and
# fixing) HAProxy is the student's job:
#
#   haproxy -c -f /etc/haproxy/haproxy.cfg     # validate
#   haproxy -D -f /etc/haproxy/haproxy.cfg     # start (daemon)
#   pkill haproxy                              # stop before a restart

ip link set eth1 up
ip addr add 172.16.0.10/24 dev eth1 2>/dev/null || true
ip route del default 2>/dev/null || true
ip route add default via 172.16.0.1 2>/dev/null || true

echo "[lb] Ready — 172.16.0.10/24, gw 172.16.0.1. HAProxy installed but not started."
