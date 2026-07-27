# Answer Key — Troubleshooting Methodology Topic Quiz

**Total:** 30 points

## A1 — A defensible repair (3 points)

- Define affected users/services/time/direction, form ranked hypotheses, and collect
  evidence that separates them rather than only confirming one favorite. (1)
- Change the smallest causal element and preserve before/after evidence. (1)
- Verify from the affected user and relevant infrastructure/control boundary. A guess may
  restore service accidentally, leave the cause present, or create hidden regressions.
  (1)

## A2 — Red flags (3 points)

- Shotgun changes destroy causal isolation and can create secondary faults. (1)
- Workarounds such as deleting DNS records, disabling security, or forcing alternate
  paths can hide the symptom without repairing the failed mechanism. (1)
- Without explicit verification, neither the original service nor collateral paths,
  resilience, and policy are proven, so apparent recovery is not a completed incident.
  (1)

## B1 — “The portal is down” (8 points)

1. DNS, client routing, forward delivery, and return routing are healthy enough for the
   SYN to reach the service host. The process listens only on loopback, so it cannot
   answer traffic addressed to `10.250.40.10`. (3)
2. Bind the intended service to the approved non-loopback address or wildcard according
   to security policy; do not alter DNS/routing. (2)
3. Verify the listener on the intended address/port, observe SYN/SYN-ACK and completed
   TCP/HTTP at the host, and perform the original client name-based request while checking
   unrelated/unauthorized access remains constrained. (3)

## C1 — Work a multi-layer incident (10 points)

- Reproduce and scope by VLAN, source, destination, protocol, time, and direction; save a
  known-good comparison from another VLAN. (2)
- Check endpoint address/gateway/DNS/ARP and access-port VLAN/state/counters before moving
  outward. (2)
- Verify SVI/gateway and routing adjacency/RIB/FIB, then trace forward and return paths
  with route lookup and captures. (2)
- Confirm service listener/application health and stateful/ACL policy counters at each
  boundary. (2)
- Stop changing once evidence localizes one cause; preserve outputs, make the minimum
  fix, and rerun original plus negative/regression tests from endpoint and infrastructure.
  (2)

## D1 — Prove a PMTUD diagnosis (6 points)

- Hypothesize that the path MTU is below the transfer size and ICMP fragmentation-needed
  or IPv6 Packet Too Big is blocked, so small exchanges pass while large DF traffic
  stalls/retransmits. (2)
- Prove with DF size sweep, TCP capture showing repeated large segments/no progress, path
  MTU/interface evidence, and missing or denied ICMP policy counter. (1)
- Repair the actual MTU mismatch or permit required PMTUD ICMP narrowly; MSS clamping may
  be a documented boundary tool, not a substitute for unexplained changes. (1)
- Eliminate server slowness, DNS, generic loss, and application-size limits with captures,
  logs, and alternate-size/path tests. (1)
- Verify large client download, observed ICMP/learned PMTU or correct packet sizing, and
  unchanged small/unrelated traffic. (1)

## Remediation

| Weak area | Review |
|---|---|
| Scope, minimal repair, transcript evidence, and endpoint verification | `labs/troubleshooting-range/` |
| Campus Layer-2/access evidence method | `labs/troubleshooting-range-campus/` |
| Edge BGP/NAT/PMTUD fault isolation | `labs/troubleshooting-range-advanced/` |
