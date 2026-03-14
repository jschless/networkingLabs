#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

prefix="$(lab_prefix)"

echo "Known syslog files:"
docker exec "${prefix}-syslog" find /var/log/remote -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort || true
echo
echo "Recent syslog lines:"
docker exec "${prefix}-syslog" sh -lc 'for f in /var/log/remote/*.log; do [ -f "$f" ] || continue; echo "== $(basename "$f") =="; tail -n 10 "$f"; echo; done'
