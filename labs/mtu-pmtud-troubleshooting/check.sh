#!/usr/bin/env bash
# Asserts the SOLVED end state — run after the MTU fix from the README.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "mtu-pmtud-troubleshooting"

nsh() { docker exec "clab-${TOPO_NAME}-$1" sh -c "$2" 2>/dev/null; }

check_contains "edge-a GRE tunnel up" "$(nsh edge-a 'ip -d link show gre1')" "gre"
check_ping_linux "host-a→host-b service IP (small packets)" host-a 192.168.2.10

# The README's exact-size probe: 1348-byte UDP with DF set must get a reply
# once the MTU problem is fixed.
probe_out=$(docker exec "clab-${TOPO_NAME}-host-a" python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3)
s.setsockopt(socket.IPPROTO_IP, 10, 2)
s.sendto(b'x' * 1348, ('192.168.2.10', 9999))
print(s.recvfrom(4096))
" 2>&1)
check_contains "1348-byte DF probe answered end to end" "$probe_out" "192\.168\.2\.10"

summary
