# debug-gre-basics platform probe

## Decision

This lab is a **Guided Debug** companion to the completed `gre-basics` build.
The critical `gw-a` and `gw-b` roles use native `ceos:4.35.2F`; there is no
critical-role FRR/Linux exception. `host-a`, `host-b`, and the routed
`internet` transit are incidental `ops-lab:local` Linux scaffolding with no
routing daemon.

## Main-supplied legacy probe observations

This table records observations supplied by the main orchestrator from its
live probe. The implementation worker did not deploy the lab or rerun these
commands.

| Area | Main-observed behavior |
|------|------------------------|
| Source syntax | Legacy `tunnel source EthernetN` was dropped by current `ceos:4.35.2F`, leaving the source `UNKNOWN`; `tunnel source interface Ethernet2` on `gw-a` and `... Ethernet1` on `gw-b` was accepted |
| Forwarding scaffolding | The prior one-shot `EOS_FORWARD` deletion was susceptible to late rule insertion; the completed paired build established a CLI-ready helper followed by 30 seconds of stable target-rule absence |
| Intended fault boundary | With only the reciprocal source syntax and forwarding scaffolding corrected, both `Tunnel0` headlines showed up/up while reciprocal tunnel and private-LAN pings failed |
| Runtime diagnosis | Exact `gw-b` detail reported that the tunnel destination next hop was part of a recursive route-resolution loop and was resolved over another tunnel |
| Underlay controls | Reciprocal far public WAN endpoint pings passed with 0% loss during the fault |
| Fault capture | A timed `-i any` transit capture for three pings observed six duplicated forward GRE/readable requests and zero reverse GRE packets or replies |
| Minimal live repair | Changing only the live `gw-b` destination removed the recursive detail; reciprocal tunnel and private-LAN pings passed |
| Healthy capture | The transit capture observed six duplicated forward and six reverse GRE packets, with six readable requests and six replies |
| Persistence | Startup hashes remained unchanged across the live repair |

## Implementation diagnostic history

The following attempts were diagnostic and are not counted as accepted clean
validation cycles:

1. The first implementation deployment exposed two checker-contract defects:
   the state library's double-quoted awk expression expanded `$2` under
   `set -u`, and runtime detail incorrectly expected the source-interface name.
   Actual EOS detail renders `Tunnel source 203.0.113.X, destination ...`;
   the source interface remains available in running configuration. The same
   implementation worker fixed both issues, and main destroyed the topology
   cleanly.
2. The next deployment passed the exact incident helper, but the healthy
   checker reported **50/5** because `0% packet loss|bytes from` matched the
   suffix of `100% packet loss`. The same worker replaced all four EOS ping
   matchers with a delimiter-safe success test. Main again destroyed cleanly.
3. The first reviewer-fix deployment confirmed all canonical learner-interface
   sections, but exposed two renderer assumptions: Linux management routes had
   trailing line whitespace, and current cEOS rendered no running or saved
   `ip route vrf` lines. The same worker normalized only line-ending whitespace
   and made the exact allowed VRF-route inventory empty. Main destroyed this
   diagnostic deployment cleanly.

These attempts are retained as diagnostic history. The **48/7** incident result
below is historical pre-review evidence; the current strengthened checker has
new accepted totals.

## Pre-review accepted current-image observations

With the pre-review code, a fresh deployment satisfied the exact incident helper:
native sources were resolved, only the `gw-b` destination was wrong, both
tunnel headlines remained up/up, recursive detail appeared on `gw-b`, both far
public controls passed, and reciprocal tunnel and LAN traffic failed. The
healthy checker rejected that incident with **48 passed / 7 failed** under the
pre-review checker.

The bounded fault capture returned exact
`forward:reverse:requests:replies` counts of **6:0:6:0**. The minimal live
repair removed recursion and produced **55/0** under that checker; the healthy
capture returned **6:6:6:6**. These packet and forwarding observations remain
historical evidence, but the checker totals are not current after reviewer
hardening. Full clean-cycle, negative, lifecycle, resource, and cleanup
evidence is recorded in [VALIDATION.md](VALIDATION.md).

## Accepted reviewer-hardened observations

The read-only reviewer found management-plane inventory gaps, permissive
interface-section matching, and a missing incident up/up predicate. The same
implementation worker tightened those contracts. In a fresh current-code
cycle, the exact incident helper returned status 0 and both tunnel headlines
explicitly matched up/up. The healthy checker rejected the incident with
**71/7**, retaining the same seven causal failures. Missing-description,
shutdown, Linux management address/route, and running/saved VRF-route negatives
were each rejected before repair mutation and restored exactly.

The current fault capture returned **6:0:6:0**. Minimal repair and idempotent
solution each returned **78/0**, and the healthy capture returned **6:6:6:6**.
Normal fault/recovery and accepted `ERR`/`INT`/`TERM` rollback also returned to
**78/0** with current startup hashes unchanged. Exact evidence is in
[VALIDATION.md](VALIDATION.md).

## Read-only review closure

The same reviewer closed all three prior findings: exact Linux management
`eth0` and cEOS VRF-route inventories, exact canonical declarations plus
operational up/up state, and the incident up/up predicate. It returned no new
actionable findings and found the implementation, README, capture, rollback,
cleanup, and evidence boundaries consistent. Read-only bash syntax,
ShellCheck, YAML, Markdown, and diff checks passed; scope was clean and
`.claude` remained untouched.

## Scope and limits

The observations are specific to the repository's local `ceos:4.35.2F` image.
They do not establish behavior on every EOS release or physical forwarding
hardware. GRE is intentionally clear text in this exercise.

`lab-tutor` is unavailable. `labs/AUTHORING.md` is the fallback instructional
contract; no tutor validation is claimed. Main reran all applicable static and
repository gates against the final current code successfully. The same
reviewer approved the lab under the `labs/AUTHORING.md` fallback.
