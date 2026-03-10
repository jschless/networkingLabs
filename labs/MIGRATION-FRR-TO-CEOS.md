# FRR to cEOS Migration Status

## Converted in this pass
- two-routers
- ospf-auth
- ospf-default-route
- ospf-multiarea
- ospf-nssa
- ospf-summarization
- ospf-virtual-link
- debug-ospf-auth
- debug-ospf-bgp-redist
- debug-ospf-multiarea
- debug-ospf-nssa
- bfd-bgp
- bfd-ospf
- ipv6-ospf3
- isis-basics
- isis-multiarea
- debug-isis-basics
- debug-spine-leaf
- debug-dmvpn-phase1
- debug-gre-basics
- dmvpn-phase1 (re-based on existing cEOS variant)
- gre-basics (re-based on existing cEOS variant)
- spine-leaf (re-based on existing cEOS variant)
- vxlan-evpn (re-based on existing cEOS variant)
- ip-sla-tracking
- route-maps-pbr
- vrrp
- enterprise-campus ISP node (FRR -> cEOS)
- gre-ipsec internet node (FRR -> cEOS)

## Intentionally kept FRR in this pass
- eigrp-basics
- eigrp-stub
- eigrp-variance
- debug-eigrp-basics
- redistribution-tags

## Remaining FRR-first labs (pending further migration/prototyping)
- debug-mpls-sr-isis-bgp
- debug-vxlan-evpn
- mpls-sr-blank
- mpls-sr-isis-bgp
- mpls-sr-srlinux
- route-maps-pbr
- vrrp
- vxlan-evpn-srlinux

## Notes
- Default cEOS image used for converted router nodes: `ceos:4.35.2F`.
- Converted labs now use `startup-config` files for cEOS nodes.
- Non-router FRR utility nodes were not globally replaced in this pass.
