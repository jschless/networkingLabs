#!/bin/bash
# fw1 — firewall node 1 (the default MASTER).
# Addresses interfaces + sets the sysctls the lab depends on. It does NOT
# start keepalived, nftables, or conntrackd — those are yours to build.

# OUTSIDE / INSIDE / SYNC
ip addr replace 10.10.0.2/24  dev eth1
ip addr replace 10.10.20.2/24 dev eth2
ip addr replace 10.10.99.1/30 dev eth3
ip link set eth1 up; ip link set eth2 up; ip link set eth3 up

# A firewall forwards between segments.
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# THE lab-critical sysctl: with tcp_loose=1 (the default) conntrack will
# "pick up" a mid-stream TCP packet it has no entry for and treat it as
# ESTABLISHED — which would mask the failover problem entirely. Setting it
# to 0 makes an orphaned mid-stream packet INVALID, so a stateful ruleset
# drops it. (Task 3 explains why this is the honest setting for an HA pair.)
sysctl -w net.netfilter.nf_conntrack_tcp_loose=0 >/dev/null

echo "[fw1] eth1=10.10.0.2 eth2=10.10.20.2 eth3=10.10.99.1; ip_forward=1, tcp_loose=0"
