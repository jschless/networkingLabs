#!/usr/bin/env bash
set -euo pipefail
event="${1:?usage: $0 EVENT_ID}"
prefix=clab-advanced-security-architecture

echo "== Stateful firewall/NAT counters =="
docker exec "$prefix-ngfw" nft -a list ruleset | grep -E 'counter|dnat|masquerade' || true
echo
echo "== Suricata events =="
docker exec "$prefix-ngfw" grep -F "$event" /var/log/suricata/eve.json 2>/dev/null || true
echo
echo "== WAF and origin/PEP correlation =="
docker exec "$prefix-security-services" grep -F "event=$event" /var/log/asa/central.log 2>/dev/null || true
