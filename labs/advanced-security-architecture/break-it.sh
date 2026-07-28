#!/usr/bin/env bash
set -euo pipefail
name=clab-advanced-security-architecture-ngfw
if docker exec "$name" nft -a list chain inet asa forward | grep -q 'BREAKIT broad partner origin bypass'; then
    echo "Break-It rule is already present."
    exit 0
fi
docker exec "$name" nft insert rule inet asa forward \
    iifname eth4 oifname eth2.120 ip saddr 10.114.40.10 ip daddr 10.114.20.20 \
    tcp dport 8080 counter accept comment '"BREAKIT broad partner origin bypass"'
echo "Injected the shadowing broad allow. Diagnose from symptoms, counters, and log gaps."
