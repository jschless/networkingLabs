#!/usr/bin/env bash
# Asserts the SOLVED end state — run after completing the README tasks
# (PIM on the routed core links + IGMP/PIM on the receiver SVIs).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-multicast"

check_contains "core1 has PIM neighbors" \
  "$(eos core1 'show ip pim neighbor')" "10\.255\."
check_contains "dist1 has a PIM neighbor toward core1" \
  "$(eos dist1 'show ip pim neighbor')" "10\.255\."
check_contains "dist2 has a PIM neighbor toward core1" \
  "$(eos dist2 'show ip pim neighbor')" "10\.255\."
check_contains "dist2 Vlan30 runs PIM (receiver SVI)" \
  "$(eos dist2 'show running-config interfaces Vlan30')" "pim"
check_ping_linux "recv-remote→its gateway" recv-remote 10.20.30.1

summary
