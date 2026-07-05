#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks
# (DHCP option 6 fixed and the client lease renewed).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "dhcp-dns-troubleshooting"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "dnsmasq running on services1" \
  "$(nsh services1 'pgrep -a dnsmasq')" "dnsmasq"
check_contains "client1 learned the correct resolver (option 6)" \
  "$(nsh client1 'cat /etc/resolv.conf')" "10\.10\.10\.53"
check_ping_linux "client1→app by IP" client1 10.10.10.80
check_contains "client1 resolves app.internal.lab" \
  "$(nsh client1 'dig +short app.internal.lab A')" "10\.10\.10\.80"

summary
