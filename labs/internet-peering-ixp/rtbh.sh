#!/usr/bin/env bash
# Runtime-only RTBH event. This mirrors a scoped IXP blackhole request and is
# intentionally reversible; it never modifies a source-mounted configuration.
set -euo pipefail
case "${1:-}" in
  inject)
    for route_server in rs1 rs2; do
      docker exec "clab-internet-peering-ixp-$route_server" vtysh -c 'conf t' \
        -c 'ip prefix-list CONTENT-IN seq 20 permit 198.51.100.66/32'
    done
    docker exec clab-internet-peering-ixp-peer-content vtysh -c 'conf t' \
      -c 'ip route 198.51.100.66/32 Null0' \
      -c 'ip prefix-list CONTENT-OUT seq 20 permit 198.51.100.66/32' \
      -c 'ip prefix-list RTBH-PREFIX seq 10 permit 198.51.100.66/32' \
      -c 'route-map CONTENT-OUT permit 5' \
      -c 'match ip address prefix-list RTBH-PREFIX' \
      -c 'set community 65010:666 additive' \
      -c 'router bgp 65002' -c 'address-family ipv4 unicast' \
      -c 'network 198.51.100.66/32'
    ;;
  clear)
    docker exec clab-internet-peering-ixp-peer-content vtysh -c 'conf t' \
      -c 'router bgp 65002' -c 'address-family ipv4 unicast' \
      -c 'no network 198.51.100.66/32'
    docker exec clab-internet-peering-ixp-peer-content vtysh -c 'conf t' \
      -c 'no ip route 198.51.100.66/32 Null0' -c 'no ip prefix-list CONTENT-OUT seq 20' \
      -c 'no ip prefix-list RTBH-PREFIX seq 10' -c 'no route-map CONTENT-OUT permit 5'
    for route_server in rs1 rs2; do
      docker exec "clab-internet-peering-ixp-$route_server" vtysh -c 'conf t' \
        -c 'no ip prefix-list CONTENT-IN seq 20'
    done
    ;;
  *) echo "usage: $0 {inject|clear}" >&2; exit 2;;
esac
