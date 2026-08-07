#!/usr/bin/env bash
# Move TRANSIT-IN to the wrong ingress interface. Re-running is idempotent.
set -euo pipefail

ROUTER="clab-acl-basics-router"

docker exec "$ROUTER" Cli -p 15 -c $'enable\nconfigure\ninterface Ethernet1\n   no ip access-group TRANSIT-IN in\ninterface Ethernet2\n   no ip access-group TRANSIT-IN in\ninterface Ethernet3\n   ip access-group TRANSIT-IN in\nend' >/dev/null

echo "Fault injected. Diagnose from traffic outcomes, attachment state, and counters."
