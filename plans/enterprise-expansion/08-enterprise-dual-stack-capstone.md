# WP-08 — Systemic Enterprise Dual-Stack Capstone

## Outcome

Build `labs/enterprise-dual-stack-capstone/`, a compact but end-to-end enterprise
whose campus, edge, DNS, DHCP, applications, monitoring, and security policy operate
over both IPv4 and IPv6. The lab should expose the common production failure where
IPv4 is healthy, DNS publishes AAAA, and IPv6 is broken—making applications appear
intermittent or client-specific.

Target coverage: level 4. Do not retrofit the 29-service grand capstone in this
package; earn the design in a smaller topology first.

## Scope and fidelity

Live:

- routed dual-stack campus with redundant distribution/default gateway;
- OSPFv2 and OSPFv3 or a deliberately chosen common IGP design;
- eBGP IPv4/IPv6 at the edge;
- SLAAC, RDNSS and stateful/stateless DHCPv6 comparison;
- DHCP/DNS/relay behavior and A/AAAA/ip6.arpa;
- IPv4/IPv6 policy parity and first-hop security achievable on the platform;
- dual-stack application behavior, source selection, Happy Eyeballs observation;
- IPv6 PMTUD, RA/ND/DAD capture, and monitoring;
- optional NAT64/DNS64 only after a Jool probe succeeds.

Conceptual/evidence: ASIC RA guard/DHCPv6 guard/ND inspection features unavailable
on the chosen image, and production multi-prefix renumbering.

## Feature-probe gate

1. Verify cEOS OSPFv3, IPv6 VRRP or selected FHRP behavior, IPv6 ACLs, RA guard,
   DHCPv6 guard, and ND inspection individually on 4.35.2F.
2. Use only features that work in the container data plane; move missing guards to
   Linux or evidence-only with explicit labels.
3. Verify Kea DHCPv6 plus relay and BIND/Unbound forward/reverse updates.
4. Verify endpoint source selection and a deterministic Happy-Eyeballs test tool.
5. Probe Jool NAT64 and DNS64 separately. Include only if clean deploy/destroy and
   kernel-module requirements are safe; otherwise keep as a future extension.

## Lab type and platform

- Type: capstone practice.
- `dist1`, `dist2`, `edge`: cEOS.
- `isp`: FRR or cEOS based on resource probe.
- `services`: Linux with Kea DHCPv4/v6, BIND/Unbound, syslog/metrics.
- `corp-client`, `guest-client`, `app-v4v6`, `app-v4only`, `internet-test`: Linux.

## Topology/addressing

```text
 corp-client -- dist1 ==== dist2 -- edge -- isp -- internet-test
 guest-client --/       \-- services
                         \-- app-v4v6 / app-v4only
```

Use paired prefixes:

| Segment | IPv4 | IPv6 |
|---|---|---|
| Corp | `10.108.10.0/24` | `2001:db8:108:10::/64` |
| Guest | `10.108.20.0/24` | `2001:db8:108:20::/64` |
| Services | `10.108.30.0/24` | `2001:db8:108:30::/64` |
| Apps | `10.108.40.0/24` | `2001:db8:108:40::/64` |
| Routed links | sequential `/30`s | sequential `/64`s |
| Public test | `198.18.108.0/24` | `2001:db8:ffff:108::/64` |

Prebuild interface addressing, base services, test apps, and one known-good
management path. Withhold dynamic routing, RA/DHCPv6 policy, DNS publication,
security policy parity, and edge advertisements.

## Student task sequence

1. **Guided baseline:** inventory link-local/global addresses, neighbor cache,
   empty OSPF/BGP tables, RA/DHCP state, and A/AAAA records.
2. **Hinted campus routing:** configure OSPFv2/v3 and redundant gateway behavior;
   verify topology parity and identify intentional protocol differences.
3. **Hinted client addressing:** configure corp SLAAC plus managed DHCPv6 options,
   guest SLAAC/RDNSS, DHCPv4, and relay. Explain M/O flags and validate leases.
4. **Hinted DNS:** publish forward and reverse v4/v6 data, enforce source-aware
   internal answers, and verify updates from address services if included.
5. **Hinted edge:** advertise approved v4/v6 aggregates to ISP with equivalent
   prefix policy and return routes; no more-specific or ULA leak.
6. **Hinted security parity:** implement corp/guest/app policy in both families and
   verify that a denied service cannot be reached over the alternate family.
7. **Hinted application behavior:** compare `curl -4`, `curl -6`, default resolver
   behavior and captured connection attempts; observe fallback timing.
8. **Open renumbering case:** introduce a second IPv6 prefix, overlap preferred and
   valid lifetimes, and produce a no-outage renumber plan from observed address state.
9. **Break-It:** remove the IPv6 return route or block ICMPv6 Packet Too Big on the
   app/edge path while leaving IPv4, DNS, routing adjacencies, and small IPv6 probes
   healthy. Diagnose why clients with AAAA preference see stalls, repair the intended
   route/ICMPv6 policy, and prove both small and large transfers.

## Make the invisible visible

- Capture RA, RS, NS, NA, DAD, DHCPv6 and PMTUD ICMPv6.
- Compare IPv4 ARP with IPv6 ND without reducing ND to “ARP for IPv6.”
- Display source/destination selection and fallback timing.
- Compare v4/v6 route and policy tables side by side.
- Monitor address preferred/valid lifetime during renumbering.

## Automated checks

`check.sh` must assert at minimum:

1. All intended OSPFv2 and OSPFv3 adjacencies are healthy.
2. Gateway redundancy works in both families as implemented.
3. Corp and guest receive correct v4/v6 addresses, routes and DNS.
4. A, AAAA and reverse records return correctly by source zone.
5. Approved aggregates only are advertised in both families.
6. Corp reaches dual-stack app over v4 and v6.
7. Guest reaches public test but not internal app over either family.
8. Security policy matrix is identical where intended.
9. Large v6 transfer and PMTUD succeed.
10. IPv4-only app behavior is clear and deterministic.
11. No ULA/link-local/more-specific leak reaches ISP.
12. Break-It fails the large-transfer/application assertion while basic probes may pass.
13. Clean redeploy has no stale leases/neighbors/routes.

## Planned files/docs

- Standard lab files plus service image/configs, deterministic client test tool,
  `PROBE.md`, and `VALIDATION.md`.
- `docs/tracks/enterprise/enterprise-dual-stack-capstone.md`; cross-register in
  Operations and IPv6 study paths.
- Update EIT IPv6 note to point here without implying EIT itself became dual-stack.

## Resource target

- 3–4 cEOS + 6 Linux.
- Target ≤ 8 GiB steady and ≤ 10 GiB peak.

## Definition of done

All master gates apply. Validate every v4/v6 positive and negative path, FHRP/failover,
DNS source behavior, PMTUD and large transfers, renumber lifetimes, and clean service
state. The Break-It must resist “delete the AAAA record” as a passing workaround.
