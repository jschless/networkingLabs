#!/usr/bin/env bash
set -euo pipefail
mkdir -p /runtime/pki
chmod -R a+rwx /runtime
if [[ ! -s /runtime/pki/ca.key ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes -keyout /runtime/pki/ca.key -out /runtime/pki/ca.crt -days 2 -subj '/CN=orchestrated-wan-lab-ca' >/dev/null 2>&1
fi
ip addr add 10.113.40.2/24 dev eth1
ip link set eth1 up
nohup python3 /pki.py >/tmp/pki.log 2>&1 &
