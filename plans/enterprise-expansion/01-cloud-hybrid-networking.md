# WP-01 — Cloud and Hybrid Networking

## Outcome

Build `labs/cloud-hybrid-networking/`, a provider-neutral practice lab that
teaches the routing and security semantics common to AWS, Azure, and GCP without
pretending that local containers are provider control planes. The student connects
an on-premises enterprise to two isolated cloud application networks through a
transit hub, publishes private DNS, centralizes inspection, and diagnoses a
route/policy interaction that presents as an application outage.

Target coverage: level 4. Follow-on blind tickets are defined in WP-13.

## Scope and fidelity

Live:

- eBGP hybrid attachment and redundant tunnels/links;
- transit-hub route-table association and propagation behavior;
- isolated application routing domains;
- stateful workload policy versus stateless subnet policy;
- centralized north-south/east-west inspection;
- private DNS and split-horizon resolution;
- flow logs, conntrack, captures, and path tests;
- overlapping-prefix failure and explicit translation/renumber decision.

Mapped conceptually in a provider comparison table:

- AWS VPC/TGW/security group/NACL/Route 53 Resolver;
- Azure VNet/Virtual WAN or hub VNet/NSG/UDR/Private DNS;
- GCP VPC/Network Connectivity Center/firewall policy/Cloud DNS.

Not claimed: real IAM APIs, managed-gateway implementation, cloud billing,
availability-zone underlay, Direct Connect/ExpressRoute/Interconnect provisioning,
or provider GUI workflows.

## Feature-probe gate

Before scaffolding the full lab, prove in a disposable topology:

1. Linux VRFs can represent three independent cloud route tables and forward
   through a common transit namespace.
2. `nftables` conntrack can model stateful workload policy while a separate chain
   models stateless subnet ACLs in both directions.
3. cEOS 4.35.2F establishes the required eBGP sessions to the Linux/FRR transit
   edges and fails over within the documented convergence window.
4. The proposed DNS server supports views or source-aware responses deterministically.
5. The generic host kernel supports every required namespace, VRF, and conntrack
   operation after destroy/redeploy.

Record exact nftables hooks and route-table IDs. If per-VRF conntrack behavior is
unreliable, use separate Linux router containers per cloud routing domain rather
than weakening isolation.

## Lab type and platform

- Type: practice lab with a final open design task.
- `onprem-edge1`, `onprem-edge2`: cEOS.
- `cloud-transit`, `inspection`: Linux custom image `cloud-lab:local`.
- `app-a-rtr`, `app-b-rtr`: Linux/FRR only because they model managed cloud route
  tables and need Linux policy hooks; document this exception.
- `dns`, clients, and apps: `cloud-lab:local` Linux.
- Pin the base image and all packages. The image should contain FRR, nftables,
  conntrack, bind/unbound, curl, dig, tcpdump, iperf3, jq, and the check helpers.

## Topology and addressing

```text
 corp-client -- onprem-edge1 ==== cloud-transit ==== app-a-rtr -- app-a
                    |                 ||
                onprem-edge2          ||== app-b-rtr -- app-b
                                      ||
                                  inspection
                                      |
                                private-dns
```

Use `/30` routed links and these logical ranges:

| Segment | Prefix | Purpose |
|---|---|---|
| On-premises | `10.60.10.0/24` | Corporate client |
| Hybrid attachment 1 | `169.254.60.0/30` | Edge1 to transit |
| Hybrid attachment 2 | `169.254.60.4/30` | Edge2 to transit |
| Cloud transit A | `10.60.100.0/30` | Transit to app A router |
| Cloud transit B | `10.60.100.4/30` | Transit to app B router |
| Inspection | `10.60.100.8/30` | Central firewall path |
| App A | `10.61.10.0/24` | Production application |
| App B | `10.62.10.0/24` | Development application |
| Shared services | `10.63.10.0/24` | Private DNS/logging |
| Conflict fixture | `10.60.10.0/24` | Deliberate overlapping cloud prefix, disabled initially |

Preconfigure interfaces, IPs, base services, loopbacks, and app listeners. Withhold
BGP, transit associations/propagations, workload policies, subnet ACLs, DNS
forwarding, and inspection steering.

## Student task sequence

1. **Guided inventory:** inspect empty transit tables, cloud router tables, DNS
   state, and denied application paths. Predict which control plane owns each hop.
2. **Hinted hybrid routing:** configure redundant eBGP attachments, accepted
   prefixes, local preference, and failover. Verify advertised/received routes on
   both sides; no catch-all redistribution.
3. **Hinted transit segmentation:** associate App A, App B, and shared-services
   attachments with separate route tables. Propagate only approved prefixes.
   Prove App A and App B remain mutually isolated.
4. **Hinted centralized inspection:** steer approved on-prem-to-App-A traffic
   through `inspection`; enforce symmetric return routing and log both directions.
5. **Hinted policy layers:** allow HTTPS with a stateful workload policy, then add
   the required reverse-direction stateless subnet rule. Compare failure evidence
   when each layer denies the flow.
6. **Hinted private DNS:** publish `api.prod.corp` privately, forward the on-prem
   zone through the resolver seam, and verify that public/untrusted clients do not
   receive the private answer.
7. **Open overlap decision:** enable the conflicting App B fixture, demonstrate
   ambiguous routing, and implement one approved response: renumbering, isolated
   non-transitive domain, or tightly scoped translation. The solution uses the
   simplest deterministic option; alternatives are evaluated in challenge questions.
8. **Break-It:** a transit route exists, DNS resolves, and TCP SYN reaches App A,
   but return traffic bypasses inspection because the App A association points at
   the wrong table. Diagnose from flow logs, capture both firewall interfaces,
   repair the association, and prove policy—not a host route workaround—restores HTTPS.

## Make the invisible visible

- Show per-domain route tables before and after propagation.
- Capture the same flow on both inspection interfaces.
- Display conntrack state for the stateful policy case.
- Compare stateful-policy logs with stateless ACL counters.
- Resolve the private name from authorized on-prem, App A, App B, and an untrusted
  source and explain the different answers.

## Automated checks

`check.sh` should make at least these assertions:

1. Both hybrid BGP sessions are established.
2. Edge1 is preferred and Edge2 is viable backup.
3. Only approved on-prem and cloud prefixes cross the seam.
4. App A reaches shared DNS.
5. App B reaches shared DNS.
6. App A and App B cannot connect directly.
7. Corporate client reaches App A HTTPS by private name.
8. Corporate client cannot reach App B's restricted port.
9. Inspection sees both request and reply counters.
10. Public/untrusted client receives no private DNS answer.
11. No cloud router has an unintended default route.
12. No overlapping fixture prefix is active in golden state.
13. Shutting primary attachment preserves the service through backup within the bound.
14. Restoring primary returns the documented preference without a long-lived asymmetric flow.

The check must fail during the Break-It even if a student adds a host route that
masks the symptom; assert the intended table association and inspection counters.

## README and challenge design

Include provider-neutral terminology first and a separate translation table for
AWS/Azure/GCP names. Challenge questions should cover blast radius, route-table
scale, cloud-managed HA, DNS resolver placement, overlapping mergers/acquisitions,
and why packet reachability does not prove policy correctness.

## Planned files and docs

- `labs/cloud-hybrid-networking/topology.clab.yml`
- `labs/cloud-hybrid-networking/Dockerfile`
- `labs/cloud-hybrid-networking/PROBE.md`
- `labs/cloud-hybrid-networking/VALIDATION.md`
- `labs/cloud-hybrid-networking/README.md`
- `labs/cloud-hybrid-networking/check.sh`
- `labs/cloud-hybrid-networking/configs/...`
- `docs/tracks/enterprise/cloud-hybrid-networking.md`
- Enterprise and Operations track registration, image table, nav, card counts,
  study path, and enterprise-wide coverage entries.

## Resource target

- 2 cEOS + 8 lightweight Linux nodes.
- Target steady state: ≤ 5 GiB; peak: ≤ 7 GiB.
- Target readiness: ≤ 120 seconds after images exist.

## Definition of done

All master-plan gates apply. Additionally, validation must include primary-link
failure during an established HTTPS session, a fresh-session failover test, policy
denies at both layers, private DNS isolation, the overlap exercise, and packet/log
evidence matching every README claim.

