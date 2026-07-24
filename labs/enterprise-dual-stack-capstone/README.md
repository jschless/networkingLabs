# Enterprise Dual-Stack Capstone — Practice Lab

Operate a compact enterprise where IPv4 and IPv6 have independent control, name,
policy, and return paths. The key production lesson is that a published AAAA record
does not prove a usable IPv6 application path.

## Topology

```text
corp-client -- dist1 ==== dist2 -- guest-client
                  \\       \\-- app-v4v6 / app-v4only
                   edge -- isp -- internet-test
                     \\\-- services (BIND + Kea configuration)
```

| Segment | IPv4 | IPv6 |
|---|---|---|
| Corp / guest / services / apps | 10.108.10/20/30/40.0/24 | 2001:db8:108:10/20/30/40::/64 |
| Campus links | 10.108.101/102/105.0/30 | 2001:db8:108:101/102/105::/64 |
| Public test | 198.18.109.0/24 | 2001:db8:ffff:109::/64 |

`dist1`, `dist2`, and `edge` are cEOS 4.35.2F; `isp` is FRR 10.5.0. The
application and service nodes are Linux. Addresses and base services are supplied;
the exercise is the operational comparison and controlled policy/routing changes.

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure.** Commit to an answer before touching the CLI.
- **Open the hints before the solution.** The solution toggle is an answer key.
- **Verify like an operator.** Prove state with show commands before moving on.

## Deploy

```bash
docker build -t enterprise-dual-stack-tools:local labs/enterprise-dual-stack-capstone/
./scripts/lab.sh deploy enterprise-dual-stack-capstone
./scripts/lab.sh check enterprise-dual-stack-capstone
```

Use `./scripts/lab.sh cli enterprise-dual-stack-capstone dist1` for EOS and
`./scripts/lab.sh bash enterprise-dual-stack-capstone corp-client` for endpoints.

## Task 1 — Inventory the dual-stack baseline (guided)

**Objective:** Record global and link-local addresses, neighbour state, DNS records,
and the initially converged routing tables.

**Predict first:** Which address family can reach `app.corp.example` first when both
records are present, and what evidence would distinguish resolver preference from a
routing failure?

```bash
./scripts/lab.sh cli enterprise-dual-stack-capstone dist1
show ip ospf neighbor
show ipv6 ospf neighbor
show ipv6 neighbors
./scripts/lab.sh bash enterprise-dual-stack-capstone corp-client
dig @10.108.30.10 app.corp.example A AAAA
ip -6 address show; ip -6 route
```

<details markdown="1"><summary>Check your work</summary>

Record at least one `fe80::` neighbour separately from global addressing. OSPFv3 uses
link-local next hops; it is not IPv4 OSPF with longer addresses.

</details>

## Task 2 — Compare OSPFv2 and OSPFv3 (hinted)

**Objective:** Verify campus reachability has equivalent IPv4 and IPv6 control-plane
coverage across `dist1`, `dist2`, and `edge`.

**Predict first:** Why can the same 32-bit router ID appear in both protocol families?

<details markdown="1"><summary>Hints</summary>

- On EOS inspect `show ip ospf neighbor` and `show ipv6 ospf neighbor`.
- Compare `show ip route ospf` with `show ipv6 route ospf`; inspect interface scope.

</details>
<details markdown="1"><summary>Solution</summary>

The supplied reference uses `router ospf 108` plus `ipv6 router ospf 108`; transit interfaces
need `ip ospf area 0` and `ipv6 ospf 108 area 0`. Keep access links passive.

</details>
<details markdown="1"><summary>Check your work</summary>

Both families show two full neighbours at the edge-facing distribution topology and
routes to the opposite campus prefixes. The router ID remains IPv4-format by protocol
design, not by data-plane address-family choice.

</details>

## Task 3 — Interpret SLAAC, RDNSS, and DHCPv6 (hinted)

**Objective:** Compare SLAAC/RDNSS on guest with managed DHCPv6 options for corp,
then validate the supplied Kea configuration without treating DHCPv6 as a default
gateway protocol.

**Predict first:** What do RA M/O flags request, and where does a host learn its IPv6
default route?

<details markdown="1"><summary>Hints</summary>

- Capture `icmp6` types 133–136 and UDP 546/547 on a client-facing link.
- Validate the service config with `kea-dhcp6 -t /etc/kea/kea-dhcp6.conf`.

</details>
<details markdown="1"><summary>Solution</summary>

Use RA for the default router and prefix lifetime. Set M when address assignment is
stateful and O when only additional configuration is requested; advertise RDNSS in
the RA where stateless DNS discovery is intended. Keep relay deployment as a planned
production extension until the access segment is moved to a shared L2 domain.

</details>
<details markdown="1"><summary>Check your work</summary>

`ip -6 route` identifies a router learned from ND, while a DHCPv6 lease/configuration
does not itself create the default route. The Kea syntax test must exit zero.

</details>

## Task 4 — Publish and reverse-resolve both families (hinted)

**Objective:** Verify A, AAAA, IPv4 reverse, and IPv6 reverse records and explain the
source-zone boundary.

**Predict first:** Does deleting AAAA repair a broken IPv6 path, or merely hide it?

<details markdown="1"><summary>Hints</summary>

- Query BIND directly with `dig @10.108.30.10`.
- Use `dig -x` for both a v4 and v6 address; inspect `/etc/bind` on services.

</details>
<details markdown="1"><summary>Solution</summary>

Publish `app` as A `10.108.40.10` and AAAA `2001:db8:108:40::10`; retain the A-only
`v4only` name. Maintain matching `in-addr.arpa` and `ip6.arpa` zones.

</details>
<details markdown="1"><summary>Check your work</summary>

The dual-stack app has two forward answers and a reverse answer. `v4only` has no
AAAA, making its different behavior intentional and deterministic.

</details>

## Task 5 — Verify edge advertisements and return paths (hinted)

**Objective:** Inspect IPv4 and IPv6 eBGP at `edge`/`isp`; advertise only approved
enterprise aggregates and prove the return path.

**Predict first:** Which symptom differs when the forward path works but ISP lacks
the IPv6 return aggregate?

<details markdown="1"><summary>Hints</summary>

- Compare `show ip bgp summary` with `show bgp ipv6 unicast summary`.
- At ISP, inspect received routes; reject ULA, link-local, and more-specific leakage.

</details>
<details markdown="1"><summary>Solution</summary>

Advertise only `10.108.0.0/16` and `2001:db8:108::/48` from AS 65108. The FRR peer
uses AS 65000 and announces the public test prefixes back.

</details>
<details markdown="1"><summary>Check your work</summary>

Both sessions are Established. ISP has no `fc00::/7`, link-local, or individual
campus /64 advertisements.

</details>

## Task 6 — Enforce policy parity (hinted)

**Objective:** Ensure guest can reach the public test but cannot reach the internal
application over either IP family.

**Predict first:** What happens if a deny exists only in the IPv4 ACL?

<details markdown="1"><summary>Hints</summary>

- Compare `show ip access-lists GUEST-V4` and `show ipv6 access-lists GUEST-V6`.
- Test the same service with `curl -4` and `curl -6`.

</details>
<details markdown="1"><summary>Solution</summary>

Apply the IPv4 ingress ACL on `dist2` Ethernet1. The cEOS image accepts IPv6 ACL
definition but not its data-plane interface attachment in this probe; use the supplied
guest Linux nftables output policy as the explicitly labeled IPv6 enforcement fallback.
Do not block ICMPv6 wholesale: ND and PMTUD depend on it.

</details>
<details markdown="1"><summary>Check your work</summary>

Guest reaches public IPv4 but neither address of the internal app. A successful
alternate-family connection is a policy-parity defect, not a workaround.

</details>

## Task 7 — Observe application selection and PMTUD (hinted)

**Objective:** Compare forced family requests with the resolver default and capture
connection attempts, RA/ND, DAD, and ICMPv6 Packet Too Big.

**Predict first:** Why can a small IPv6 ping pass while an application transfer stalls?

<details markdown="1"><summary>Hints</summary>

- Run `curl -4`, `curl -6`, and default `curl` to the app.
- Capture `tcpdump -ni eth1 'icmp6 or port 53 or port 8080'`; use a payload larger
  than the constrained path MTU for a PMTUD observation.

</details>
<details markdown="1"><summary>Solution</summary>

Use separate forced-family requests before interpreting default resolver behavior.
Happy Eyeballs is an implementation timing choice; capture actual SYN attempts rather
than assuming a fixed winner or delay.

</details>
<details markdown="1"><summary>Check your work</summary>

The capture distinguishes RS/RA, NS/NA, and DAD from ARP. A received Packet Too Big
updates the sender's path MTU; it is control traffic required for IPv6 delivery.

</details>

## Task 8 — Plan a no-outage renumber (open)

**Objective:** Introduce `2001:db8:208::/48` alongside the old prefix and write a
no-outage plan using observed preferred and valid lifetimes.

**Predict first:** Which lifetime should become zero first, and why?

<details markdown="1"><summary>Hints</summary>

- Capture an RA before and after the change and inspect `ip -6 address` lifetimes.

</details>
<details markdown="1"><summary>Solution</summary>

Advertise both prefixes, make the old prefix deprecated by setting its preferred
lifetime to zero while retaining a nonzero valid lifetime, verify DNS and return
routes for the new prefix, then withdraw only after observed sessions drain.

</details>
<details markdown="1"><summary>Check your work</summary>

The old address remains valid but is no longer preferred; a route/DNS cutover before
that overlap is a deliberately avoided outage risk.

</details>

## Task 9 — Break-It: diagnose IPv6-only application stalls (open)

**Objective:** Keep IPv4, DNS, and OSPF adjacencies healthy while blackholing the
application segment's IPv6 return route. Diagnose from evidence, restore the
minimal route, and prove the service again. Do **not** delete the AAAA record.

```bash
./labs/enterprise-dual-stack-capstone/break-it.sh
./scripts/lab.sh check enterprise-dual-stack-capstone --break-it
```

<details markdown="1"><summary>Hints</summary>

- Compare `show ipv6 route 2001:db8:108:10::/64` at dist2 before changing DNS or endpoint settings.
- Trace forward and return family paths independently; the broken return affects v6 replies.

</details>
<details markdown="1"><summary>Solution</summary>

Remove only dist2's static `2001:db8:108:10::/64 Null0` route, then run
`./labs/enterprise-dual-stack-capstone/repair-break-it.sh` and recheck. Deleting AAAA
conceals the fault and fails this task.

</details>
<details markdown="1"><summary>Check your work</summary>

IPv4 remains healthy during the incident, but the IPv6 return route is absent. After
the minimal repair the route and v6 application test recover without a DNS edit.

</details>

## Verification

Run `./scripts/lab.sh check enterprise-dual-stack-capstone`. It checks OSPFv2/v3,
eBGP families, aggregate hygiene, A/AAAA/reverse DNS, positive dual-stack service,
guest isolation, and Break-It state.

## Challenge questions

1. How would you add an actual shared-L2 access segment and FHRP without changing the policy tests?
2. Which operational telemetry distinguishes PMTUD loss from DNS latency?
3. How would you model source-aware DNS answers for internal and guest clients?
4. What health check would prevent an AAAA record from outliving IPv6 reachability?

## Troubleshooting

| Symptom | Evidence | Minimal correction |
|---|---|---|
| v4 works; v6 app stalls | dist2 blackholes the app return route | Remove the scoped IPv6 Null0 route; retain AAAA |
| Guest reaches app over one family | ACL tables differ | Add the equivalent family-specific deny |
| Name resolves but connection fails | `dig` succeeds, route/capture does not | Trace both directions before changing DNS |
| Large v6 transfer fails | PTB absent/blocked | Permit required ICMPv6 and retest PMTUD |

## Limitations

The cEOS container probe did not prove ASIC RA guard, DHCPv6 guard, ND inspection,
or IPv6 VRRP behavior. They are evidence-only or Linux-enforced design controls here;
production multi-prefix renumbering is a procedure exercise, not a hardware claim.
