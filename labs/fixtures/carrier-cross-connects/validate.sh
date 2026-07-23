#!/usr/bin/env bash
set -euo pipefail
grep -q '2.2 dB' physical-evidence.md
grep -q 'B-to-C is wrong' physical-evidence.md
grep -q 'T1/SONET' physical-evidence.md
grep -q 'Silver.*3120' service-order.md
echo 'fixture deductions: PASS (budget, patch, legacy boundary, service map)'
