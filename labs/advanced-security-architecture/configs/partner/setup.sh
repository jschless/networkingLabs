#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.114.40.10/24 dev eth1
ip link set eth1 up
ip route replace default via 10.114.40.1
python3 /opt/lab/issue_token.py >/run/partner.token
chmod 0600 /run/partner.token
