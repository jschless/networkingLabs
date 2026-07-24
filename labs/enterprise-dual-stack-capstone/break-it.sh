#!/usr/bin/env bash
set -euo pipefail
# Preserve IPv4, DNS, and adjacencies while blackholing the app segment's IPv6 return route.
docker exec clab-enterprise-dual-stack-capstone-dist2 Cli -p 15 \
  -c $'enable\nconfigure\nno ipv6 route 2001:db8:108:10::/64 2001:db8:108:101::1\nipv6 route 2001:db8:108:10::/64 Null0\nend' >/dev/null
echo 'Break-It active: app IPv6 return route blackholed at dist2. Do not delete the AAAA record.'
