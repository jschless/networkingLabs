#!/usr/bin/env bash
# Task 7 — apply the fault. Run from anywhere; then diagnose FROM THE SYMPTOM
# (your scripts against r1 stop working). Don't read this file first — that's
# the answer key.
set -euo pipefail

docker exec clab-automation-fundamentals-r1 Cli -p 15 -c "configure
management api http-commands
no protocol http
protocol https
end" >/dev/null

echo "Fault applied to r1. Re-run your Task 4 script and start diagnosing."
