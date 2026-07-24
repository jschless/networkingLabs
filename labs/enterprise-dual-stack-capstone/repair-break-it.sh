#!/usr/bin/env bash
set -euo pipefail
docker exec clab-enterprise-dual-stack-capstone-dist2 Cli -p 15 \
  -c $'enable\nconfigure\nno ipv6 route 2001:db8:108:10::/64 Null0\nipv6 route 2001:db8:108:10::/64 2001:db8:108:101::1\nend' >/dev/null
echo 'App IPv6 return path restored.'
