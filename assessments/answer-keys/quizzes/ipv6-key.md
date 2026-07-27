# Answer Key — IPv6 and Dual-Stack Operations Topic Quiz

**Total:** 30 points

## A1 — Host configuration is not one protocol (3 points)

- An RA Prefix Information Option supplies the on-link prefix and autonomous-address
  parameters used by SLAAC. (1)
- The host installs its default router from Router Advertisements; DHCPv6 does not
  provide an IPv6 default-gateway option. (1)
- DNS can arrive through RDNSS in an RA or through stateless/stateful DHCPv6, according
  to the advertised design and host support. A global address therefore proves neither
  default-route nor DNS readiness. (1)

## A2 — IPv6 routing control planes (3 points)

1. Link-local addresses are guaranteed on the link and keep adjacency/next-hop identity
   independent of global prefix renumbering; the outgoing interface supplies their
   required scope. (1)
2. Type-1 Router-LSAs carry topology without prefixes, Type-8 Link-LSAs carry per-link
   link-local/prefix information, and Type-9 Intra-Area-Prefix-LSAs associate intra-area
   prefixes with topology. (1)
3. MP-BGP carries IPv6 NLRI and its IPv6 next hop in `MP_REACH_NLRI`; extended-next-hop
   capability lets this occur over an IPv4-transport session. (1)

## B1 — One session, one broken family (8 points)

1. Session state and received-prefix count prove the control plane exchanged IPv6 NLRI,
   not that its next hop resolves or the route reached the FIB. IPv4 success is
   independent because activation, policy, and next-hop handling are per AF. (2)
2. The advertised IPv6 next hop `2001:db8:12::2` is unreachable, so the BGP path cannot
   be installed in the IPv6 routing table. (2)
3. Award 1 point each for two relevant causes: missing `next-hop-self` in the IPv6 AF on
   an iBGP boundary; a route map setting an invalid IPv6 next hop; or missing IPv6
   underlay/connected reachability required to resolve the advertised next hop. Do not
   award activation as the primary cause when eight IPv6 prefixes are already received.
   (2)
4. Verify the IPv6 AF path and next-hop resolution, then the IPv6 RIB/FIB; test the
   destination from a remote IPv6 source and prove the return path, preferably with
   forced-family application traffic rather than relying on dual-stack fallback. (2)

## C1 — Select a coexistence design (10 points)

1. **Dual stack:** run both families end to end so applications and destinations migrate
   independently while both paths are operated and secured. (2)
2. **NAT64 with DNS64:** synthesize an IPv6 destination for the IPv4-only service and
   translate at the NAT64 boundary. Direct literal-IPv4 and protocols embedding
   addresses require special consideration. (3)
3. **6PE:** dual-stack PEs exchange labeled IPv6 routes while the IPv4/MPLS core forwards
   a transport plus 6PE label stack and does not learn customer IPv6 routes. (3)
4. Apply equivalent IPv6 policy at the correct interface/zone and verify both families.
   Do not block ICMPv6 wholesale because ND and PMTUD depend on it. (2)

## D1 — Renumber without an outage (6 points)

- Advertise the new prefix while retaining the old one, and establish new routing plus
  valid return paths before preferring it. (1)
- Publish/validate new AAAA and reverse DNS records while both addresses remain usable.
  (1)
- Make the old prefix's preferred lifetime zero first so hosts stop selecting it for new
  sessions, while retaining a nonzero valid lifetime for existing use. (1)
- Duplicate security, monitoring, DHCPv6/RDNSS, and service policy for the new prefix;
  test forced IPv6 and normal dual-stack application behavior, including PMTUD. (1)
- Observe address lifetimes and active sessions, then withdraw the old DNS/routing/RA
  advertisement only after the planned drain and cache intervals. (1)
- Verify from client and return-path viewpoints and retain a rollback window. Disabling
  IPv6 or deleting AAAA merely hides a failed migration. (1)

## Remediation

| Weak area | Review |
|---|---|
| RA, SLAAC, DHCPv6, and IPv6 DNS | `labs/ipv6-access-services/` |
| OSPFv3 link-local operation and LSAs | `labs/ipv6-ospf3/` |
| MP-BGP address-family and next-hop handling | `labs/ipv6-bgp/` |
| Dual stack, NAT64/DNS64, and 6PE selection | `labs/ipv6-transition/` |
| Policy parity, PMTUD, and renumbering | `labs/enterprise-dual-stack-capstone/` |
