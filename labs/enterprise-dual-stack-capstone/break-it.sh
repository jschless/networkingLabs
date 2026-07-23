#!/usr/bin/env bash
set -euo pipefail
# Preserve IPv4 and small IPv6 probes; only remove the ISP's IPv6 return route.
docker exec clab-enterprise-dual-stack-capstone-isp vtysh -c 'configure terminal' -c 'router bgp 65000' -c 'address-family ipv6 unicast' -c 'no network 2001:db8:ffff:109::/64' -c 'end'
echo 'Break-It active: IPv6 return advertisement withdrawn at isp. Do not delete the AAAA record.'
