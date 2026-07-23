#!/usr/bin/env bash
# Runtime-only stale-IRR injector.  It neither edits source-mounted configs nor
# restarts a container. The added route is legitimate but absent from AS65003.txt.
set -euo pipefail
case "${1:-}" in
  inject)
    docker exec clab-internet-peering-ixp-peer-saas vtysh -c 'conf t' \
      -c 'ip route 192.0.3.0/24 Null0' \
      -c 'ip prefix-list SAAS-OUT seq 20 permit 192.0.3.0/24' \
      -c 'router bgp 65003' \
      -c 'address-family ipv4 unicast' -c 'network 192.0.3.0/24'
    ;;
  clear)
    docker exec clab-internet-peering-ixp-peer-saas vtysh -c 'conf t' \
      -c 'router bgp 65003' -c 'address-family ipv4 unicast' \
      -c 'no network 192.0.3.0/24' -c 'no ip route 192.0.3.0/24 Null0' \
      -c 'no ip prefix-list SAAS-OUT seq 20'
    ;;
  *) echo "usage: $0 {inject|clear}" >&2; exit 2;;
esac
