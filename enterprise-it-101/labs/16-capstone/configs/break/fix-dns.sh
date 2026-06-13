#!/bin/bash
# Part B, Break #1 — DNS repair. Run INSIDE dns1:
#   docker exec dns1 bash /break/fix-dns.sh
set -e
sed -i 's/forwarders { 10.100.1.99; }/forwarders { 10.100.1.10; }/' /etc/bind/named.conf
rndc reconfig
rndc flush
echo "[fix-dns] lab.corp conditional forwarder restored to dc1 (10.100.1.10)."
