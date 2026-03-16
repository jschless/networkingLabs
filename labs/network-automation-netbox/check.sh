#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "network-automation-netbox"

retry_contains() {
  local name="$1"
  local cmd="$2"
  local regex="$3"
  local attempts="${4:-18}"
  local delay="${5:-5}"
  local out=""
  local i

  for ((i=1; i<=attempts; i++)); do
    out=$(eval "$cmd")
    if echo "$out" | grep -qE "$regex"; then
      pass "$name"
      return 0
    fi
    sleep "$delay"
  done

  fail "$name" "expected /$regex/ in output"
  return 1
}

retry_contains "spine1 BGP Established" "eos spine1 'show bgp summary'" "Established"
retry_contains "spine2 BGP Established" "eos spine2 'show bgp summary'" "Established"
retry_contains "leaf1 BGP Established" "eos leaf1 'show bgp summary'" "Established"
retry_contains "leaf2 BGP Established" "eos leaf2 'show bgp summary'" "Established"
check_ping_eos "spine1→leaf2 loopback" spine1 10.255.0.14
check_ping_eos "leaf1→spine2 loopback" leaf1 10.255.0.12
retry_contains \
  "netbox UI reachable" \
  "node automation 'python3 -c \"import urllib.request; print(urllib.request.urlopen(\\\"http://172.31.40.23:8080\\\", timeout=5).status)\"'" \
  "200" \
  24 \
  5
retry_contains \
  "netbox render-config works" \
  "node automation 'bash -lc \"cd /workspace && python3 seed_netbox.py >/dev/null && python3 render_from_netbox.py\"'" \
  "Rendered 4 configs from NetBox" \
  12 \
  5

summary
