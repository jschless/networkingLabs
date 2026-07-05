#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "macsec-basics"

check_contains "r1 MACsec config present" \
  "$(vyos_op r1 "show configuration commands | match 'interfaces macsec macsec0'")" \
  "interfaces macsec macsec0"
check_contains "r2 MACsec config present" \
  "$(vyos_op r2 "show configuration commands | match 'interfaces macsec macsec0'")" \
  "interfaces macsec macsec0"
check_ping_vyos "r1→r2 plain Ethernet" r1 198.51.100.2
check_ping_vyos "r1→r2 MACsec" r1 192.0.2.2
check_ping_vyos "r2→r1 plain Ethernet" r2 198.51.100.1
check_ping_vyos "r2→r1 MACsec" r2 192.0.2.1

summary
