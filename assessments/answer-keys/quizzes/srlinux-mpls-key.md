# Answer Key — SR Linux SR-MPLS Operations Topic Quiz

**Total:** 20 points

## A1 — Map the service stack (4 points)

- The default network instance carries the underlay, IS-IS/SR reachability, global BGP,
  and transport forwarding; an `ip-vrf` network instance isolates customer routes. (1)
- `bgp-vpn` supplies RD/RT import/export behavior, while
  `l3vpn-ipv4-unicast` is the VPNv4 control-plane AF. (1)
- The SRGB plus node SID maps a prefix SID index to a predictable transport label. (1)
- The MPLS forwarding table supplies push/swap/pop operations; the service/VRF label at
  the egress PE selects the customer context. (1)

## B1 — VPN route exists globally, not in the customer table (6 points)

- Transport and global VPNv4 receipt are healthy. RT 65000:100 does not match CUST-A's
  import RT 65000:200, so the route is not imported into the customer RIB. (3)
- Correct the intended CUST-A import RT/policy to 65000:100 without changing IS-IS/SR.
  (1)
- Verify global VPNv4 route, CUST-A imported route/next hop, customer-label/transport
  LFIB, and bidirectional CE application/ping. Any three checks earn 2 points. (2)

## C1 — Verify one customer packet (5 points)

Award 1 point for each linked boundary:

1. CE has the remote route/default and sends to its PE.
2. Ingress PE VRF resolves the VPN route with correct RT/next hop and service label.
3. Global VPNv4 control state and SR route to the egress PE agree.
4. Transit LFIB shows the expected transport push/swap/PHP and egress service selection.
5. Remote PE VRF/CE route and sourced return traffic complete bidirectionally.

## D1 — Operate a YANG-based NOS safely (5 points)

- Enter candidate state, make scoped modeled changes, and inspect validation/diff before
  commit. (1)
- Use explicit import/export routing policy; default deny prevents accidental acceptance
  but can create a clear missing-policy outage. (1)
- Commit only validated intent with rollback/checkpoint access. (1)
- Verify operational adjacency, routes, labels, VRF import, and user path rather than
  candidate/config presence alone. (1)
- A default-accept CLI workflow can leak unintended prefixes immediately; modeled
  candidate transactions reduce partial changes but do not replace policy testing. (1)

## Remediation

| Weak area | Review |
|---|---|
| SR Linux network instances, SR-MPLS, VPNv4, RT policy, and CLI operations | `labs/mpls-sr-srlinux/` |
