#!/usr/bin/env bash
set -euo pipefail
docker exec clab-enterprise-dual-stack-capstone-isp vtysh -c 'configure terminal' -c 'router bgp 65000' -c 'address-family ipv6 unicast' -c 'network 2001:db8:ffff:109::/64' -c 'end'
echo 'IPv6 return advertisement restored.'
