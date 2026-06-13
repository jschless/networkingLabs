#!/bin/bash
# Part B, Break #1 — DNS. Run INSIDE dns1:
#   docker exec dns1 bash /break/break-dns.sh
#
# Points dns1's lab.corp conditional forwarder at a black-hole IP, so the
# resolver can no longer reach the AD DNS on dc1. lab.corp names stop resolving
# for every client that uses dns1 — which presents downstream as broken logins
# and "can't reach the DC", not as an obvious DNS fault.
set -e
sed -i 's/forwarders { 10.100.1.10; }/forwarders { 10.100.1.99; }/' /etc/bind/named.conf
rndc reconfig
rndc flush          # drop cached lab.corp answers so the break bites immediately
echo "[break-dns] lab.corp conditional forwarder now points at 10.100.1.99 (black hole)."
echo "[break-dns] Symptom: clients can no longer resolve dc1.lab.corp via dns1."
