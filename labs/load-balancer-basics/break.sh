#!/usr/bin/env bash
# Task 6 — apply the fault. Run from anywhere, then diagnose FROM THE SYMPTOM.
# Don't read this file first — that's the answer key.
set -euo pipefail

docker exec clab-load-balancer-basics-web1 ip route replace default via 172.16.0.2

echo "Fault applied. Exercise the service from the client and start diagnosing."
