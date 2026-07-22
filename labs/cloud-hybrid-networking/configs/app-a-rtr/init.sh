#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.60.100.2/30 dev eth1
ip addr add 10.60.100.14/30 dev eth2
ip addr add 10.61.10.10/32 dev lo
for interface in eth1 eth2 lo; do ip link set "$interface" up; done
mkdir -p /run/cloud-lab
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=api.prod.corp' \
  -keyout /run/cloud-lab/key.pem -out /run/cloud-lab/cert.pem >/dev/null 2>&1
cat /run/cloud-lab/key.pem /run/cloud-lab/cert.pem > /run/cloud-lab/server.pem
nohup sh -c 'while true; do openssl s_server -accept 10.61.10.10:8443 -cert /run/cloud-lab/cert.pem -key /run/cloud-lab/key.pem -www -naccept 1; done' \
  >/run/cloud-lab/api.log 2>&1 &
