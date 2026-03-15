#!/bin/bash
# Spoke1 setup — creates GRE tunnel to hub, adds simulated LAN, loads FRR config.

sysctl -w net.ipv4.ip_forward=1

# GRE tunnel with fixed remote = hub WAN IP.
# Phase 1: all spoke-to-spoke traffic routes through hub (OSPF p2mp gives hub as NH).
ip tunnel add tun0 mode gre local 10.0.0.11 remote 10.0.0.1 ttl 64 dev eth1
ip addr add 172.16.0.11/24 dev tun0
ip link set tun0 up

# Simulated LAN behind spoke1
ip addr add 192.168.1.1/24 dev lo

vtysh -b
