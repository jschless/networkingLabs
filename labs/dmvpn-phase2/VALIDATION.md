# dmvpn-phase2 — Validation Record

## Status

The final compatibility-reference design passed repeated clean live workflows
before independent review. After deterministic transient-state reset and
seeding, the pre-strengthening checker repeatedly returned **109/0**. The
supported live-only service-host fault failed only its intended
spoke1-to-spoke2 relationship while the hub registrations, iBGP, remote
overlay mappings, and unrelated service paths remained healthy. Normal,
idempotent, and forced-TERM recovery each restored that pre-strengthening
**109/0** state.

Independent review then required exact saved/live learned-interface subtree
comparison and fail-closed parsing of every shortcut-table data row. The
interface change added eight assertions. A fresh rebuilt topology passed the
strengthened checker at **117/0**.

The main agent's first strengthened run returned **109/8**. Exactly the eight
new live/saved interface-subtree comparisons failed; every other assertion
passed. On all four routers, both live and saved command sets contained the
VyOS-normalized leaves `set interfaces ethernet eth1 offload gso` and
`set interfaces ethernet eth1 offload sg`, while every other expected
interface line matched. Those two exact leaves are now part of each role's
reference. The post-fix fresh run confirmed the corrected reference at
**117/0**.

At least two clean final-code deployment/destroy cycles completed. A third
disposable cycle used for atomic negatives was also cleanly destroyed. After
each final destroy there were zero target containers, no generated
`clab-dmvpn-phase2` directory, and no target helper/capture process.

The lab tutor was unavailable. Student-flow validation therefore used
`labs/AUTHORING.md` as the fallback contract and does not claim tutor
validation. Repository-wide gates passed as recorded below. Independent
review remains open pending the same reviewer's follow-up after these fixes.

## Environment and role ownership

Validation ran on amd64 with:

| Component | Observed value |
|-----------|----------------|
| ContainerLab | `0.74.1` |
| VyOS software | Rolling release `2026.03.15-0031` |
| Critical roles | Native `vyos:local` on `hub`, `spoke1`, `spoke2`, and `spoke3` |
| Incidental role | `ops-lab:local` on the `br-wan` Ethernet bridge |

All learned NHRP, BGP, recursive-route, and forwarding behavior belongs to the
four native VyOS routers. The Linux bridge performs only incidental Layer 2
forwarding and bridge-wide packet observation, so no critical-role Linux/FRR
exception applies.

## Fresh pre-traffic transition

On the final clean deployment, spoke1's NHRP shortcut table was initially
empty. Its BGP RIB already held `192.168.2.0/24` with remote spoke overlay next
hop `172.16.0.12`, but the kernel FIB resolved service traffic through the
bootstrap path:

```text
via 172.16.0.1 dev tun0
```

This observed transition is the central compatibility lesson. BGP preserved
the next-hop property needed by classic Phase 2, but direct forwarding did not
appear through ordinary next-hop resolution. It required the configured hub
Traffic Indication (`redirect`) and spoke `shortcut` behavior.

## Deterministic seeding and exact healthy state

The final seeder first bounded-cleared only ephemeral NHRP shortcut/cache state
on all three spokes, then sent bounded source-specific traffic until every
direction had both:

- an exact remote-overlay-to-NBMA dynamic mapping; and
- a direct kernel FIB through `tun0`, with or without the remote overlay shown
  explicitly as `via`.

All six final source-specific service pings then succeeded. The complete
pre-strengthening checker repeatedly returned **109/0**. It required exact
node/image ownership, operational WAN/tunnel/service address sets, mGRE
semantics, live and saved BGP/NHRP/static configuration, hub registration
cardinality/correlation, iBGP inventory, preserved remote-spoke BGP next hops,
direct FIBs, all six service paths, and direct bridge-wide packet evidence.
The post-review checker additionally compares the exact learned `eth1`,
`tun0`, and `dum0` configuration subtrees in both live and saved state and
examines every shortcut-table data row. The fresh rebuilt topology passed that
complete strengthened contract at **117/0**.

## Optional transient-state discovery

Live validation disproved the early assumption that every healthy direction
must contain both a dynamic service-host NHRP row and a service-prefix shortcut
row. After one reset, spoke3 had:

- the exact dynamic `172.16.0.12 → 10.0.0.12` remote overlay mapping;
- no dynamic `192.168.2.1` service-host row;
- no `192.168.2.0/24` row in `show ip nhrp shortcut`;
- a direct kernel FIB `via 172.16.0.12 dev tun0`; and
- successful direct service traffic.

The stable invariant is therefore the remote overlay mapping plus direct FIB
and traffic, not the optional diagnostic rows. The final checker permits zero
to two remote service-host rows and zero to two service-prefix shortcut rows
per spoke, but only when every present row is correlated to the correct NBMA
or remote overlay. The post-review parser examines every non-heading shortcut
data row, so non-dynamic rows cannot be silently discarded; it rejects
duplicates, miscorrelations, and all unexpected NHRP or shortcut rows. This
strengthened parsing was included in the fresh **117/0** run.

## Bridge-wide direct-path proof

After deterministic reset/seeding, the bounded bridge-wide capture collected
exactly four records for one request/reply observed at bridge ingress and
egress. It contained:

- outer GRE `10.0.0.11 > 10.0.0.12` for the request;
- outer GRE `10.0.0.12 > 10.0.0.11` for the reply; and
- no spoke1-to-hub or hub-to-spoke2 outer leg.

The four records are duplicate observation points for one request and one
reply, not four network transmissions. This directly proves that established
traffic used the spoke-to-spoke data path rather than merely inferring it from
a control-plane table.

## Focused atomic negatives

Four accepted final-checker mutations proved exact live/saved enforcement:

| Negative | Checker result | Causal assertion | Recovery |
|----------|----------------|------------------|----------|
| Add live `172.16.0.99/32` to spoke1 `tun0` | Pre-strengthening **108/1** | Exact operational tunnel address set rejected the extra address | Remove the live address; pre-strengthening **109/0** |
| Add saved-only spoke3 route `192.168.99.0/24` via the hub while live state remained healthy | Pre-strengthening **108/1** | Exact saved protocol state rejected live/saved divergence | Save the healthy live state; pre-strengthening **109/0** |
| Change only spoke3's saved `tun0` description, then restore healthy live state | Strengthened **116/1** | Only `spoke3 saved learned-interface reference is exact` failed | Save the healthy live state; **117/0** |
| Add saved-only spoke3 OSPF while live state remains OSPF-free | OSPF-aware **116/1** | Only `spoke3 saved protocol reference is exact` failed | Save the healthy live state; **117/0** |

The OSPF P1 closure began from a clean fresh deploy at **117/0**. On spoke3,
the main agent set, committed, and saved
`protocols ospf parameters router-id 10.255.255.3`, then deleted OSPF from
live state and committed without saving. Live configuration contained no
OSPF, while saved configuration contained exactly that stanza. The checker
returned atomic **116/1** with only
`spoke3 saved protocol reference is exact` failing. Saving the healthy live
state removed the saved-only stanza and recovered **117/0**.

A supplemental strengthened extra-address attempt was deliberately not
accepted as the atomic interface negative. A saved-only
`172.16.0.99/32` was detected, but adding and deleting the address from live
state left a stale local NHRP row. The checker therefore returned **114/3**
rather than isolating one assertion. A clean destroy and redeploy removed the
stale operational row before validation continued.

Earlier iterations of the final design also rejected missing hub redirect and
preconfigured static-route/map shortcuts. Those checks preceded the final
optional-transient checker semantics and are supplemental evidence; their
totals are not represented as pre-strengthening **109**-assertion results.

## Deliberate service-host fault and recovery

The final opaque fault set one live-only spoke1 map:

```text
192.168.2.1 → 10.0.0.254
```

The fault was not saved. In the accepted negative state:

- the hub retained all exact spoke registrations;
- all iBGP peers remained healthy;
- spoke1 retained the correct dynamic `172.16.0.12 → 10.0.0.12` overlay map;
- spoke1-to-spoke2 service traffic failed;
- spoke1-to-spoke3 and spoke2-to-spoke3 service traffic stayed healthy; and
- the exact healthy checker rejected the state.

A broader `192.168.2.0/24` transient shortcut could remain visible without
overriding the more-specific wrong service-host resolution, so its absence was
not used as a causal postcondition.

Normal repair deleted the complete live `map` parent, preserving the healthy
saved configuration, then invoked the central all-spoke transient reset and
seeder. In the final post-fix cycle, the deliberate fault armed with its target
spoke1-to-spoke2 failure while the unrelated control and data paths stayed
healthy. Normal repair returned the strengthened checker to **117/0**, and an
immediate idempotent repair again returned **117/0**.

Forced interruption was exercised after fault injection. Sending `TERM` made
the helper exit with status **143**. Transactional rollback removed the wrong
map, preserved saved state, reset/reseeded transient state, and independently
returned the pre-strengthening checker to **109/0**. The terminal did not
print the rollback banner, so validation relies on the independently observed
exact post-TERM state rather than claiming that message was emitted.

## Active resources

Under simultaneous tight source-specific service ping loops in all six
directions, peak observed memory was:

| Node | Peak observed memory |
|------|----------------------|
| `br-wan` | 644 KiB |
| `hub` | 267 MiB |
| `spoke1` | 263.7 MiB |
| `spoke2` | 267.4 MiB |
| `spoke3` | 268.2 MiB |

Peak aggregate memory was approximately **1.04 GiB**. Every node reported
`OOMKilled=false` and `RestartCount=0`. These are short active-load samples,
not long-duration capacity guarantees.

## Implementation corrections discovered live

Live validation corrected several early assumptions before the accepted
design stabilized:

- VyOS startup normalization removed each spoke's redundant explicit hub map
  and added `registration-no-unique`; the NHS definition still produced the
  exact runtime hub row.
- An early checker assumed every spoke always had six NHRP rows and two
  service-prefix shortcuts; live aging proved those diagnostic rows optional.
- Poisoning the remote overlay row did not causally fail already-resolved
  service. The deliberate fault moved to the more-specific service-host key.
- Removing the wrong static host leaf could leave an empty live `map` parent;
  repair now deletes the complete parent.
- Retained transient state could suppress fresh resolution. The seeder now
  resets shortcut/cache state on every spoke before rebuilding the stable
  overlay/direct-FIB contract.
- Seeder readiness and convergence bounds were tightened iteratively from live
  evidence rather than retaining optimistic success claims.

## Deploy cycles and cleanup

- The first accepted final-code cycle validated the fresh transition,
  deterministic healthy state, direct capture, deliberate fault, repair, and
  resource behavior, then destroyed cleanly.
- A second clean final-code cycle repeated the accepted healthy and lifecycle
  behavior and destroyed cleanly.
- A third disposable cycle exercised the final atomic negatives and was also
  destroyed cleanly.
- A fresh post-review rebuild passed **117/0**, isolated the accepted saved
  interface-description negative at **116/1**, recovered to **117/0**, and was
  cleanly rebuilt after the non-atomic stale-NHRP supplemental attempt.
- The final post-fix cycle armed the deliberate fault, repaired to **117/0**
  twice, and destroyed cleanly.
- The clean OSPF-aware closure cycle passed **117/0**, isolated saved-only OSPF
  at **116/1**, recovered to **117/0**, and destroyed cleanly.

After every final destroy, zero `dmvpn-phase2` containers remained, the
generated ContainerLab directory was absent, and no target seeder, checker,
fault, rollback, ping-loop, or capture process remained. The final process
check initially showed only the checking `pgrep` command matching its own
search text; that self-match was explicitly recognized and ignored, and no
actual target process remained.

The final OSPF P1 closure destroy independently left zero target containers,
zero target processes, and no generated `clab-dmvpn-phase2` directory.

## Repository gates

The main agent observed the target Bash syntax, warning-level ShellCheck, and
topology YAML checks pass. Repository Markdown spacing and admonition checks
passed. `scripts/lint-labs.py` passed with **143 labs** and **53 distinct
images**. Quiz validation passed all **44 quizzes** plus **7 regression
fixtures**, and `git diff --check` passed.

Two strict MkDocs builds passed in **29.17 s** and **29.79 s** wall time with a
maximum observed RSS of **87,928 KiB**. Both retained the repository's existing
Material-version warning and informational nav messages; neither produced a
strict-build failure. After the small review fix, the target Bash/ShellCheck/
YAML checks, Markdown/admonition checks, **143/53** lab lint, **44 + 7** quiz
checks, and diff check passed again. A post-fix strict build also passed in
**28.76 s** wall time at **87,884 KiB** maximum RSS with the same existing
warning and nav information. No live checker total is inferred from these
static results.

After the final live-evidence update, the complete post-fix gate run passed:
target `bash -n`, `shellcheck -S warning`, and topology YAML; Markdown spacing
and admonitions; lab lint at **143 labs / 53 images**; **44** quiz/key pairs,
quiz coverage, and **7** regression cases; and `git diff --check`.
`mkdocs build --strict` exited **0**, built the docs in **31.74 s**, and used
**32.28 s** wall time with **87,912 KiB** maximum RSS. Its only messages were
the existing Material warning and informational pages absent from the nav; no
new strict-build finding appeared.

The complete post-OSPF-fix gate run also passed: target Bash, warning-level
ShellCheck, and topology YAML; Markdown spacing and admonitions; lab lint at
**143 labs / 53 images**; **44** quiz/key pairs, quiz coverage, and **7**
regression cases; and the diff check. Strict MkDocs exited **0**, built the
docs in **29.57 s**, and used **30.33 s** wall time with **87,828 KiB** maximum
RSS. It retained only the same existing Material warning and informational
unnav-listed pages.

## Review status

Closed and approved. The required read-only reviewer completed an initial
final-diff review and returned four actionable findings: exact saved/live
interface-subtree grading, fail-closed shortcut-row parsing, correction of the
study-path transfer claim, and recording the already observed repository
gates. After those fixes, the same reviewer found one P1 saved-state gap: the
exact protocol comparator omitted OSPF while the separate no-OSPF assertion
inspected only live aggregate state, so saved-only OSPF could pass.

The final comparator canonicalizes BGP, NHRP, OSPF, and static protocol
commands in both live and saved state against the same OSPF-free references.
The same reviewer verified that implementation, the saved-only OSPF
**117/0 → 116/1 → 117/0** atomic sequence, clean destroy, complete post-fix
gates, every prior finding, the full diff, regressions, and scope hygiene. The
follow-up result was exactly: `No actionable findings remain.`

## Validation limits

Validation covered amd64 software/container execution on VyOS rolling
`2026.03.15-0031`. It did not cover arm64, physical VyOS appliances, hardware
offload, dual hubs, large spoke counts, long-duration operation, WAN
loss/reordering, encryption, or a future VyOS/FRR release that may restore
classic shared-subnet Phase 2 ordinary resolution. Resource figures are active
point samples rather than capacity tests.
