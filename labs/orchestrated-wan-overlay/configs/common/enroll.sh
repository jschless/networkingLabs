#!/usr/bin/env bash
set -euo pipefail
NODE="${NODE:?NODE environment is required}"
D="/runtime/edges/$NODE"
mkdir -p "$D"
openssl req -new -newkey rsa:2048 -nodes -keyout "$D/client.key" -out "$D/client.csr" -subj "/CN=$NODE" >/dev/null 2>&1
curl -fsS --data-binary @"$D/client.csr" "http://10.113.40.2:8080/enroll/$NODE" -o "$D/client.crt"
curl -fsS http://10.113.40.2:8080/ca.crt -o "$D/ca.crt"
wg genkey | tee "$D/wg.key" | wg pubkey > "$D/wg.pub"
chmod 600 "$D/client.key" "$D/wg.key"
echo "enrolled $(openssl x509 -in "$D/client.crt" -noout -serial)"
pgrep -f "/edge-agent.py $NODE" >/dev/null || nohup python3 /edge-agent.py "$NODE" >/tmp/edge-agent.log 2>&1 &
