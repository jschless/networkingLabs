# dmvpn-phase3 — Validation Record

## Status

Live validation, active-load resource sampling, and two accepted clean
deploy/destroy cycles are complete, and every applicable repository gate
passed. The initial read-only review returned one P2 stale-status/evidence
finding and no other actionable finding. The same reviewer approved the
follow-up with no new or residual actionable finding, so review is complete.
The reported pre-implementation probe is recorded separately in `PROBE.md`.

The requested lab-tutor skill is unavailable. Student-flow validation uses
`labs/AUTHORING.md` as the fallback contract and does not claim tutor
validation.

## Environment and role ownership

The accepted checker confirmed native `vyos:local` on the critical `hub`,
`spoke1`, `spoke2`, and `spoke3` roles, with `ops-lab:local` only on the
incidental `br-wan` Ethernet bridge/capture point. No critical-role FRR/Linux
exception applies.

Docker health remained `unhealthy`/systemd `degraded` on all four routers
solely because `atopacct.service` timed out on unsupported netlink process
accounting. FRR daemons, injected interfaces, and the validated routing/data
planes operated until the separate direct-restart experiment described below.
This record does not claim clean Docker health.

## Closure status

The lab-specific live validation, resource, cleanup, repository-gate, and
read-only review workflow is complete.

## Accepted first live cycle

The corrected final files passed the complete checker repeatedly at
**144 passed / 0 failed**, including an idempotent `solution.sh` run. The
accepted README walk covered the summary-only pre-traffic state, exact
hub-originated Type-2 external LSA, all six service-host NHRP mappings and
service-prefix `/24` shortcuts, direct FIB/ping state, bidirectional direct GRE
capture, and the corrected same-area service-advertisement comparison recorded
below.

Seven focused fail-closed atomics each produced exactly
**143 passed / 1 failed**, with only the intended assertion failing:

1. extra live tunnel address;
2. converged live interface description mismatch;
3. saved-only static protocol route;
4. saved-only interface description mismatch;
5. injected unexpected shortcut-table row;
6. wrong image on a critical router role; and
7. unexpected WAN bridge member.

The deliberate live-only missing-shortcut-consumer fault preserved target
reachability through the hub, all control-plane state, and an unrelated spoke
path while producing **118 passed / 26 failed**. Normal repair and an immediate
idempotent repair each restored **144/0**.

After rollback hardening, forced TERM exited **143**, forced INT exited
**130**, and injected ERR exited **97**. Every path preserved the exact saved
configuration SHA and completed its internal full checker at **144/0**. The INT
test reset the signal environment because asynchronous Bash shells inherit an
ignored INT disposition; that setup made the intended handler test explicit
rather than treating a background-shell signal no-op as recovery.

The first accepted destroy removed all lab containers, the lab network,
generated artifacts, and helper/capture processes cleanly.

## Direct-restart limitation

A direct Docker restart of the four VyOS containers retained live and saved
configuration and briefly reconverged. Containerlab-injected `eth1` and `tun0`
then disappeared from the restarted namespaces, and the post-restart checker
failed. This is **not accepted persistence or restart support**. A clean
Containerlab redeploy is required after restarting these containers; no
restart-survival claim is made.

## Accepted second live cycle and resources

The second clean final-code deployment reproduced the exact unsolved learner
baseline. Its first solution attempt encountered the premature **143/1** route
sample documented below; after the two-sample complete-routing gate was added,
repeated `solution.sh` completed at **144/0**. The final checker after active
load also passed **144/0**.

Peak maxima across two samples during active six-direction service traffic
were:

| Node | Peak memory |
|------|-------------|
| `br-wan` | 3.680 MiB |
| `hub` | 260.400 MiB |
| `spoke1` | 258.300 MiB |
| `spoke2` | 262.200 MiB |
| `spoke3` | 262.300 MiB |

The aggregate peak-maxima sum was about **1046.88 MiB (~1.02 GiB)**. Every
container reported `OOMKilled=false` and `RestartCount=0`.

The first sampling harness applied timeout on the host side of six
`docker exec ... ping` commands. The clients ended, but six ping children
remained inside the containers and recreated shortcut state while the
immediate checker was trying to observe its pre-traffic boundary. That check
failed only those disturbed pre-traffic expectations. The main orchestrator
killed the residual children and immediately recovered **144/0**, then repeated
the load with timeout inside each container, proved no ping process remained,
and again passed **144/0**. This was a non-final sampling-harness mistake, not a
lab or checker defect.

The second destroy removed every lab container, the lab network, generated lab
directory/artifacts, and helper/load processes cleanly. Together with the first
accepted destroy, the two-clean-destroy requirement is complete.

## Interrupted first live cycle

The main orchestrator's first final-code cycle exposed two implementation
defects before any learned spoke configuration changed:

- The unsolved baseline had no NHRP peer state, OSPF adjacency, or
  overlay/service-specific route. A lookup for `192.168.2.1` nevertheless
  displayed Containerlab's management default through `eth0`; the
  source-specific service ping failed. Task 1 now distinguishes that
  management fallback from DMVPN data-plane reachability.
- `solution.sh` stopped at the first spoke because the bind-mounted
  `apply-solution.sh` was mode `0700`, so the container's `admin` user received
  `Permission denied`. All target shell helpers are now mode `0755`.

This diagnostic cycle did not validate the solution, checker, fault lifecycle,
resource figures, or cleanup contract. The accepted cycles above supply those
later live results.

## Route-formatter and shortcut diagnostic cycle

A subsequent main-orchestrator cycle reached the checker and reported
**124 passed / 17 failed**. The failures exposed stale output assumptions, not
a successful final workflow:

- Every spoke printed the sole summary route as
  `O>* 192.168.0.0/16 ... via 172.16.0.1, tun0`. Independently,
  `show ip ospf database external` showed exactly one AS-external LSA with
  Link State ID `192.168.0.0`, Advertising Router `10.0.0.1`, Network Mask
  `/16`, and Metric Type 2. Route matching now follows the observed formatter,
  while a separate exact LSDB assertion proves external origin and type.
- After all six directional flows, each remote service host had a dynamic NHRP
  mapping correlated with the remote overlay and NBMA. The shortcut table used
  service-prefix routes such as
  `dynamic 192.168.2.0/24 172.16.0.12`, not service-host `/32` routes. `Via`
  was the column header, not a literal in the row. Direct host FIB lookups
  still selected the remote `tun0` path. Seeder, checker, and fault
  expectations now model all three correlated layers explicitly.

Because the checker failed and its stale seeder predicate prevented the full
accepted workflow, this cycle does not establish final checker, capture,
fault-recovery, resource, or cleanup success. The accepted cycles above supply
the later final evidence.

## Shortcut data-row diagnostic cycle

The next fresh main-orchestrator cycle applied the intended solution state but
reported **133 passed / 11 failed**. Live shortcut rows were exactly of the
form:

```text
dynamic  192.168.2.0/24           172.16.0.12
```

`Via` was a column header, not a literal field in the data row. The
implementation had inserted a literal `via` into its regexes and therefore
failed the seeder, the shortcut correlation assertions, and the dependent
capture assertion. Matchers and examples now use the observed three-field
`type prefix overlay` row contract.

Although the solution reached the intended live state, **133/11 is a failed
checker result**. This cycle does not establish final checker, capture,
fault-recovery, resource, or cleanup success; the accepted cycles above supply
the later final evidence.

## Focused interface-negative capture diagnostic

During the next main-orchestrator atomic live-interface negative, the checker
reported **142 passed / 2 failed**. One failure was the intended rejection of
the extra live interface leaf. The second was not causal to that negative:
`capture-shortcut.sh` stopped after the first four `any` records, and bridge
duplication filled those records with only the request direction before a
reply record was retained. All direct FIB and source-specific ping assertions
passed.

The capture now observes a bounded three-ping window without a fixed record
count, accepts the intentional timeout status after clean interruption, then
requires both direct outer-GRE directions and rejects every hub-facing leg for
the two spokes. Its process group is still terminated on error or signal and
the temporary capture file is removed.

Because the run contained one unrelated capture-order failure, **142/2 is not
an accepted focused negative**. A later extra-live-address rerun produced the
accepted **143/1** result listed in the first-cycle evidence.

## Focused bridge-negative capture diagnostic

A later bridge-member atomic also reported **142 passed / 2 failed**: one
failure was the intended exact bridge-inventory rejection, while the capture
reported a hub-facing GRE leg even though every direct FIB and source-specific
ping assertion passed. A standalone capture rerun showed only direct
`10.0.0.11` ↔ `10.0.0.12` GRE.

The longer-window filter had required GRE and byte 33 equal to inner protocol
1, but had not first proved that the GRE payload type was IPv4. NHRP/control
GRE could therefore alias byte 33 and enter the ICMP evidence set. The filter
now also requires GRE protocol type `0x0800` at outer IPv4 bytes 22-23 before
checking the inner IPv4 protocol byte.

Because the bridge atomic contained this unrelated filter-alias possibility,
**142/2 is not an accepted bridge negative**. A later unexpected-member rerun
produced the accepted **143/1** result listed in the first-cycle evidence.

## Same-area service-advertisement task walk

The main orchestrator tested the final Task 4 topology by adding
`set protocols ospf area 0 network 192.168.1.0/24` on spoke1's `dum0` and
clearing spoke2's transient NHRP state. Before traffic, spoke2 selected
`O>* 192.168.1.0/24 ... via 172.16.0.1` in addition to the external `/16`, and
its FIB followed the hub. This proves that a same-area service specific escapes
the hub's external summary and violates the sole-summary/O(1) contract.

After seeding, spoke2 showed
`dynamic 192.168.1.0/24 172.16.0.11` in the shortcut table. Its detailed route
for `192.168.1.1` was a `/32` known via NHRP, distance 10, best, and direct on
`tun0`; the OSPF `/24` was nonselected. The final dummy-interface topology
therefore preserves direct optimization despite the incorrect same-area
advertisement. README Task 4 now identifies the defect precisely as per-spoke
routing-state growth, not shortcut masking.

This task-walk correction is part of the accepted first-cycle mechanism
evidence. Full repository gates passed separately as recorded below; review
closure is complete as recorded below.

## Forced-TERM rollback diagnostic

The main orchestrator sent TERM to the `break.sh` process group immediately
after spoke1's live `shortcut` leaf became absent. The script exited with the
required status **143**, and the saved configuration SHA remained exact, but
it logged `ERROR: transactional rollback failed after TERM`. The live leaf
remained absent and transient shortcut seeding could not converge. A manual
`repair.sh` run subsequently restored the complete **144 passed / 0 failed**
state.

This exposed a real rollback timing defect: the killed VyOS configuration
child or lock could still be releasing when the single suppressed restore
attempt ran. The old 50-second reseed and 90-second full-check budgets were
also too tight for the observed worst-case seeder and hardened capture.

Rollback now kills and waits for active descendants as before, then retries
only the minimal live shortcut leaf under a 75-second overall deadline until
an exact live-config query proves it present. It reports restore, saved-SHA,
reseed, and full-check failures separately; reseed and full-check budgets are
now 90 and 150 seconds. The transaction still fails closed unless the saved
SHA is unchanged and the complete checker passes.

The failed TERM attempt is **not accepted transactional recovery**. Manual
**144/0** proved only that the repair path could restore health. A later TERM
rerun after rollback hardening exited 143, preserved the saved SHA, and
completed its internal **144/0**, as recorded in the accepted first cycle.

## Second-cycle convergence diagnostic

On the second clean final-code cycle, `solution.sh` observed all three hub
registrations, all three hub `Full` adjacencies, and spoke1's selected service
summary, then invoked the checker before every remote overlay route had
settled. The checker reported **143 passed / 1 failed**; the sole finding was
`spoke1 learns spoke3 overlay /32 through the hub`. That route appeared moments
later while all OSPF neighbors remained `Full`.

This was convergence churn, not an accepted focused negative or an accepted
second cycle. The solution gate now requires, on every spoke, exactly one
`Full` hub neighbor, the selected `/16` through the hub, and both remote
overlay `/32`s through the hub, in addition to the hub's three registrations
and three `Full` neighbors. The entire predicate must be true for two
consecutive samples inside the existing bounded wait before `check.sh` runs.
The accepted second-cycle section records the successful rerun.

## Repository gates

Every applicable full repository gate exited 0:

- target Bash syntax (`bash -n`);
- warning-level ShellCheck (`shellcheck -S warning`);
- topology YAML parse;
- Markdown block spacing;
- documentation admonitions;
- `lint-labs.py`: OK, 143 labs and 53 distinct images;
- `validate-quizzes.py`: OK, 44 quiz/key pairs;
- `git diff --check`; and
- `mkdocs build --strict`, with only the existing Material advisory and
  existing pages-not-in-nav informational notices.

## Review status

The initial read-only reviewer reported one actionable P2: current status,
remaining-work, gate, review, and limit wording had not been updated after the
completed validation/gate run. It reported no other actionable finding. This
edit resolved that stale evidence wording. The same read-only reviewer approved
the follow-up and reported no new or residual actionable finding. The sole P2
is fully resolved and review is complete.

## Validation limits

Accepted runtime claims are limited to the two live-cycle sections above. The
diagnostic failures remain historical non-acceptance evidence, and direct
Docker restart is explicitly unsupported by this result. Validation does not
cover arm64, physical VyOS appliances, hardware forwarding/offload, IPsec,
dual hubs, large scale, long-duration operation, adverse WAN conditions, or
future VyOS/FRR behavior. Resource samples are point-in-time observations, not
capacity guarantees. These scope limits do not imply that current repository
gates or review closure are incomplete; both are complete.
