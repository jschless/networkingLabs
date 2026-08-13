# dmvpn-phase1 — Validation Record

## Status

The remediated lab passed the first complete clean post-edit cycle and the
healthy and fault workflows on a fresh second deployment. The final healthy
checker repeatedly returned **91/0**. The supported live-only multicast fault
returned the stable causal result **69/22**, and normal repair and forced
transactional rollback restored **91/0**.

Both accepted deployments were cleanly destroyed. After the final destroy,
zero target containers remained, the generated ContainerLab directory was
absent, and no target or capture process remained. The lab tutor was
unavailable, so validation used `labs/AUTHORING.md` as the fallback authoring
contract and does not claim tutor validation.

## Environment and role ownership

Validation ran on 2026-08-13 on amd64 with:

| Component | Observed value |
|-----------|----------------|
| ContainerLab | `0.74.1` |
| VyOS software | Rolling release `2026.03.15-0031` |
| Critical roles | Native `vyos:local` on `hub`, `spoke1`, `spoke2`, and `spoke3` |
| Incidental role | `ops-lab:local` on the `br-wan` Ethernet bridge |

The four native routers own the learned NHRP/OSPF behavior. The Linux bridge
performs only incidental Layer 2 forwarding and packet observation, so no
critical-role Linux exception applies.

## Fresh learner baseline

The fresh baseline contained exactly the five intended nodes and image-role
mapping. WAN interfaces, mGRE tunnels, dummy service interfaces, and the hub
NHRP/OSPF server state were present. The three spoke learned subtrees were
absent.

The baseline checker returned **36/55**: underlay and scaffold assertions
passed, while dynamic NHRP registrations, OSPF adjacencies/routes, six
source-specific service paths, and packet-path evidence failed. Raw bounded
source pings were required after validation caught that the shared helper's
text match could find `0% packet loss` inside `100% packet loss`. The final
checker uses `timeout` plus the raw ping process exit status and fails closed.

VyOS startup migration added `registration-no-unique` to the hub's NHRP
server definition even when it was absent from the source. The source and
exact checker reference now state this platform-normalized hub-only default
explicitly. Spokes do not use it, and exact NHRP table correlation still
requires three distinct registrations.

## Clean learner workflow and exact healthy state

The deterministic solution deleted and rebuilt the complete learned
`protocols nhrp` and `protocols ospf` subtrees on all three spokes, committed,
saved, and converged. The observed state included:

- exactly one local plus three correlated dynamic `T` rows on the hub;
- exactly one local row and one static hub row on each spoke;
- exactly three Full hub neighbors, and exactly one Full hub neighbor on each
  spoke;
- selected remote service and tunnel routes through `172.16.0.1` on every
  spoke, while each local OSPF service route remained directly connected;
- exact matching live and saved learned definitions;
- no redirect, shortcut, fixed GRE remote, spoke-side registration bypass,
  or learned-plane static-route shortcut;
- exact WAN-bridge ports and forwarding state; and
- successful source-specific service traffic for all six spoke pairs.

The first healthy checker returned **88/3** because its route parser counted
each spoke's local OSPF-connected service prefix along with the two selected
remote service prefixes. The assertion was corrected to count selected
`O>*` remote routes while retaining exact per-peer next-hop checks. The
checker then returned **91/0** repeatedly. An immediate second solution run
again replaced the learned subtrees, converged, and returned **91/0**, proving
solution idempotence.

## Bridge-wide Phase 1 packet proof

A bounded capture on `br-wan` using `tcpdump -i any` and an inner-ICMP GRE
filter observed exactly eight records for the first request/reply of a
two-packet spoke1-to-spoke2 service ping. The duplicate ingress/egress views
showed:

- spoke1 outer `10.0.0.11 > 10.0.0.1`, arriving at the hub;
- hub outer `10.0.0.1 > 10.0.0.12`, leaving for spoke2;
- the two reverse reply legs; and
- no direct outer `10.0.0.11 > 10.0.0.12` leg.

The bounded helper completed and removed its temporary capture file/process.
This bridge-wide observation closes the blind spot of an earlier hub-only
capture and directly proves hub transit rather than inferring it only from
routes.

## Focused atomic negatives

Two reversible focused negatives tested exact configuration enforcement:

| Negative | Checker result | Causal assertion | Recovery |
|----------|----------------|------------------|----------|
| Add one extra live OSPF leaf | **90/1** | Complete live learned definition differed | Remove leaf; **91/0** |
| Add `172.16.0.111/32` to spoke1 `tun0` | **70/21** after exact-address fix | Exact tunnel address set rejected pollution; dependent NHRP/OSPF/service assertions also failed | Disposable runtime reset; fresh cycle returned **91/0** |

Removing the extra tunnel address left a stale local row in `nhrpd`'s runtime
cache. Validation did not misrepresent that contaminated runtime as recovered:
it was destroyed and the accepted workflow continued on a fresh deployment.
The final checker compares normalized exact per-interface IPv4 address sets,
so an additional address cannot pass merely because the intended one remains.

## Deliberate fault and recovery

The supported fault changed only spoke1's live NHRP multicast replication
target from `10.0.0.1` to unused `10.0.0.254` and did not save it. After the
OSPF dead interval:

- the hub retained spoke1's correlated dynamic NHRP registration;
- spoke1 retained WAN and hub-tunnel reachability;
- hub Full adjacency count fell to two and spoke1 saw the hub only in `Init`;
- spoke1 lost its remote service routes and service traffic to spoke2;
- the spoke2-to-spoke3 service path stayed healthy; and
- saved spoke1 configuration remained unchanged.

The independent checker returned **69/22** while all NHRP/underlay assertions
and the unaffected spokes2/3 path remained green. Normal repair restored only
the live multicast target, preserved saved state, and returned **91/0** on two
runs, including an immediate idempotent repair.

Forced interruption was also exercised after the live fault mutation.
Sending `TERM` caused the transactional trap to restore the exact healthy
live multicast target, retain the healthy saved value, recover all adjacencies
and service routes, and return the checker to **91/0**.

## Active resources

Under active source-specific service traffic, observed peak memory was:

| Node | Peak observed memory |
|------|----------------------|
| `hub` | 264.7 MiB |
| `spoke1` | 266.7 MiB |
| `spoke2` | 265.7 MiB |
| `spoke3` | 265.2 MiB |
| `br-wan` | 640 KiB |

Peak aggregate memory was approximately **1.04 GiB**. No node reported an
OOM kill. These are short point-in-time observations, not capacity or
long-duration stability guarantees.

## Deploy cycles and cleanup

- The first clean post-edit deployment completed the baseline, healthy,
  exact-negative, deliberate-fault, repair, rollback, capture, and resource
  workflow and was cleanly destroyed.
- A fresh second deployment reproduced the exact baseline, solution,
  **91/0** healthy state, fault **69/22**, repairs, interruption rollback, and
  packet evidence, then was cleanly destroyed.

The contaminated address-negative runtime was treated as disposable and
destroyed rather than included as an accepted recovery cycle.
After the final accepted destroy, there were zero target containers, no
generated `clab-dmvpn-phase1` directory, and no target or capture process.

## Repository gates

The following gates passed:

- target Bash syntax, ShellCheck at warning severity, YAML parsing, topology
  policy checks, and executable modes;
- Markdown block spacing and documentation-admonition checks;
- lab lint: 143 labs and 53 distinct images;
- quiz validation: 44 quiz/key pairs plus 7 validator regressions;
- `git diff --check`; and
- `mkdocs build --strict` in 29.08 seconds with maximum command RSS of
  87,636 KiB.

The strict documentation build emitted the upstream Material for MkDocs 2.0
warning and existing navigation information, then completed successfully.

## Review status

The sole read-only reviewer found two issues:

1. this validation record was still a pending placeholder despite completed
   live evidence; and
2. a capture only on hub `eth1` could not observe a forbidden direct spoke
   packet elsewhere on the shared WAN.

This record now contains the observed evidence, and the helper now captures
bridge-wide with exact required/forbidden outer pairs. The same reviewer then
completed a read-only follow-up, closed both findings, approved closure, and
returned exactly: `No actionable findings remain`.

## Validation limits

Validation covered amd64 software/container execution on VyOS rolling
`2026.03.15-0031`. It did not cover arm64, physical VyOS appliances, hardware
offload, encryption, dual-hub failover, large spoke counts, long-duration
operation, WAN loss/reordering, or upgrades from earlier VyOS releases. The
fixed-remote GRE plus native NHRP probe limitation remains documented in
`PROBE.md`; the accepted lab uses honest mGRE spokes and proves Phase 1 through
hub-preserved next hops and bridge-wide packet evidence.
