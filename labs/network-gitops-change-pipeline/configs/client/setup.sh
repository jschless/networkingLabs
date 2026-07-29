#!/usr/bin/env bash
set -eu
ip addr add 10.112.10.10/24 dev eth1
ip addr add 10.112.10.20/24 dev eth1
ip route replace default via 10.112.10.1 dev eth1
mkdir -p /var/lib/gitops-client
printf 'corp=10.112.10.10\nguest=10.112.10.20\n' > /var/lib/gitops-client/identities
nohup python3 /opt/gitops/path_agent.py >/tmp/path-agent.log 2>&1 &
