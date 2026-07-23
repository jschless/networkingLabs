# Feature Probe Record — `enterprise-dual-stack-capstone`

## Scope and decision

- **Feature and learning objective:** cEOS dual-stack OSPF/OSPFv3, IPv6 ACL syntax,
  FHRP/first-hop controls, and edge viability before building the campus capstone.
- **Decision:** documented fallback for first-hop guard/FHRP; go for routed cEOS.
- **Reason and fidelity statement:** On this host, cEOS 4.35.2F formed IPv4 OSPF and
  IPv6 OSPF adjacencies and exposed IPv6 ND state. Attempts to install IPv6 VRRP,
  RA guard, DHCPv6 guard, and ND-inspection commands did not enter running config or
  returned `Invalid input`. The lab therefore does not claim container-data-plane
  ASIC first-hop enforcement or cEOS IPv6 FHRP; those controls are evidence-only or
  Linux-policy design points. This is the fallback allowed by WP-08.
- **Owner and date:** WP-08 worker, 2026-07-23.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux 5.15.0-181-generic x86_64 |
| ContainerLab version | 0.74.1, commit 1866b3a2b (2026-03-15) |
| Docker version | client/server 29.5.3 |
| NOS/service image | `ceos:4.35.2F`, image ID `f27a0e7dba17`; EOS `4.35.2F-46221466.4352F` |
| Host memory/disk before probe | 15 GiB RAM (11 GiB available); 143 GiB disk free |

## Smallest load-bearing test

Disposable two-node topology at `/tmp/enterprise-dual-stack-probe` with one routed
IPv4/IPv6 Ethernet link. Commands (verbatim):

```text
containerlab deploy -t /tmp/enterprise-dual-stack-probe/topology.clab.yml --reconfigure
docker exec clab-enterprise-dual-stack-probe-r1 Cli -p 15 -c enable -c 'show ip ospf neighbor'
docker exec clab-enterprise-dual-stack-probe-r1 Cli -p 15 -c enable -c 'show ipv6 ospf neighbor'
docker exec clab-enterprise-dual-stack-probe-r1 Cli -p 15 -c enable -c 'show ipv6 interface Ethernet1'
docker exec clab-enterprise-dual-stack-probe-r1 Cli -p 15 -c enable -c 'configure terminal' -c 'ipv6 nd raguard policy PROBE' -c end
```

Relevant output: EOS reports `Ospf` and `Ospf3` agents; IPv4 neighbor
`10.255.1.2` formed, and IPv6 interface output included global and link-local
addresses, DAD enabled, RS/RA state, and solicited-node multicast membership.
Each attempted guard command returned `% Invalid input at line 1`. Two cEOS probe
containers used 1.28 GiB and 1.26 GiB respectively after convergence (2.54 GiB total).
Deploy completed in roughly 37 seconds to usable CLI state.

## Cleanup and repeatability

- **Destroy/cleanup command:** `containerlab destroy -t /tmp/enterprise-dual-stack-probe/topology.clab.yml --cleanup`
- **Orphans checked:** `docker ps --format '{{.Names}}' | grep enterprise-dual-stack-probe`
- **Result:** scoped destroy removed both probe containers; no matching container remained.

## Unsupported behavior and fallback

Jool NAT64/DNS64 was not added: no separate kernel/module probe was performed and it
is explicitly optional in WP-08. Kea/BIND assets are retained as versioned service
configuration; shared-L2 DHCPv6 relay and source-view updates remain follow-up work,
not a completed live claim.
