#!/usr/bin/env bash
set -euo pipefail
lab=carrier-ethernet-handoff
out="${1:-acceptance-report.md}"
{
  echo '# Carrier Ethernet Acceptance Report'; echo; echo "Generated: $(date -u +%FT%TZ)"; echo
  echo '## Measurements'; echo
  echo '```text'
  ./scripts/lab.sh cmd "$lab" tester-a -- ping -I eth1.110 -M 'do' -c 3 -s 1572 192.0.2.2
  ./scripts/lab.sh cmd "$lab" tester-a -- ping -I eth1.110 -M 'do' -c 1 -s 1573 192.0.2.2 || true
  ./scripts/lab.sh cmd "$lab" tester-a -- iperf3 -c 192.0.2.2 -B 192.0.2.1 -t 3
  echo '```'
  echo; echo '## Sign-off'; echo 'Circuit: SYNTH-CEH-001. Result: record measured result above; do not sign if any committed test fails.'
} > "$out"
