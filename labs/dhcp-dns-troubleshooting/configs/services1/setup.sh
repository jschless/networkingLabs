#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 10.10.10.53/24 dev eth1
# Work on a local copy: the bind-mounted original can't be edited in place
# (rename fails on single-file mounts) and edits must not leak into the repo.
cp /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
dnsmasq --keep-in-foreground --log-facility=/tmp/dnsmasq.log >/tmp/dnsmasq.out 2>&1 &
echo "[services1] DHCP/DNS ready on 10.10.10.53"
