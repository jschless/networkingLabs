# flexvpn-basics validation record

This record separates the implementation-worker engineering run, the main
acceptance cycles, and the later reviewer-driven checker hardening. The main
cycles used the then-current 134-assertion checker; the final hardened checker
has 143 assertions. Counts below are reported against the checker version that
actually produced them.

## Implementation-worker engineering evidence — 2026-08-24

- The target-owned, digest/package-pinned `flexvpn-lab:local` image built.
- A clean deploy began with passive hub definitions, zero SAs, and answer-free
  spokes.
- `solution.sh` was idempotent and reached 134 passed, 0 failed.
- The bounded protected capture recorded four bidirectional public ESP packets
  and no readable private packet; VTI and hairpin captures exposed the expected
  private request/reply above XFRM and on both hub VTI legs.
- `break.sh` preserved one IKE/CHILD pair on each spoke while breaking only
  spoke1 forwarding; `repair.sh` changed only the live VTI key and recovered
  134/0. ERR and TERM rollback engineering probes also recovered 134/0.

This evidence informed acceptance but did not replace the main orchestrator's
clean cycles below.

## Main acceptance — 2026-09-01

### Clean cycle 1 — 134-assertion checker

- The pinned `flexvpn-lab:local` image rebuilt successfully.
- The clean learner baseline had a passive hub with zero SAs and answer-free
  spokes.
- `solution.sh` reached exactly 134/0 and an idempotent rerun remained 134/0.
- Focused atomic negatives failed closed and recovered completely between
  mutations:

  - extra VTI/address inventory: 132 passed, 2 failed; recovery 134/0;
  - extra private route: 133 passed, 1 failed; recovery 134/0;
  - IKE definition plus extra credential pollution: 132 passed, 2 failed;
    recovery 134/0;
  - transit rule pollution: 133 passed, 1 failed; recovery 134/0.

- The deliberate VTI key `9` versus XFRM mark `1` fault produced 128 passed,
  6 failed. IKE/CHILD remained established, spoke2 forwarding and the public
  underlay remained healthy, and repeated `repair.sh` runs recovered 134/0.
- Independent transactional windows returned the requested failure codes and
  restored exact health: ERR rc 2, TERM rc 143, and INT rc 130 each recovered
  134/0.
- The protected capture collected four bidirectional ESP packets with no
  readable private packet. The VTI capture collected the private echo
  request/reply, and the hairpin capture collected that flow on both hub VTI
  legs.
- The deployment was destroyed cleanly with zero target containers, networks,
  generated directories, capture files, or temporary artifacts.

### Clean cycle 2 — 134-assertion checker

- A second clean deploy, solution, and checker reached 134/0.
- Representative protected and hairpin captures, the deliberate fault, repair,
  and final checker all passed; final health was 134/0.
- The second deployment was destroyed cleanly with zero target runtime or file
  residue.

### Active-load resource evidence

Six-direction protected traffic ran while per-node memory was sampled
repeatedly with `docker stats --no-stream`.

| Node | Observed maximum |
|---|---:|
| gw-a | 3.660 MiB |
| gw-b | 3.543 MiB |
| gw-c | 3.508 MiB |
| host-a | 0.879 MiB |
| host-b | 0.887 MiB |
| host-c | 0.891 MiB |
| internet | 0.664 MiB |

The recorded aggregate maximum was 14.031 MiB. Every container reported
`OOMKilled=false` and zero restarts. Validation ran on x86_64/amd64.

## Reviewer hardening and final checker — 2026-09-01

- One read-only reviewer raised a P2: a same-identity wrong saved PSK could
  evade redacted identity checks while an existing SA remained established,
  and unexpected marked XFRM objects could evade the subset counts.
- The same continuation worker added nonprinting exact secret hashes, exact
  total XFRM state counts, and exact total marked-policy counts while retaining
  the existing per-mark and tunnel-mode checks. Protected traffic is generated
  before fresh ESP counter state is captured and asserted.
- The hardened checker reached exactly 143 passed, 0 failed.
- With IKE still established, a wrong same-identity saved PSK produced 142
  passed, 1 failed; restoration returned 143/0.
- An extra marked non-tunnel XFRM policy left forwarding healthy but produced
  142 passed, 1 failed; restoration returned 143/0.
- The same reviewer completed the follow-up with **APPROVE** and no actionable
  findings.
- Final destroy left zero target containers, networks, generated directories,
  capture files, or temporary artifacts.

## Repository gates

The following passed, and affected gates were rerun after checker hardening:

- Markdown block spacing;
- docs admonition validation;
- lab lint: 142 labs and 53 distinct images;
- 44 quiz/key validations;
- seven quiz regression cases;
- 29-topic enterprise coverage plus positive and negative fixtures;
- Bash syntax for every target script and ShellCheck at warning severity;
- strict MkDocs build;
- `git diff --check`.

## Validation limitations

- The requested `lab-tutor` skill was unavailable. Student-flow review used
  `labs/AUTHORING.md` as the fallback contract; no tutor validation is claimed.
- Live validation covered x86_64/amd64 Linux strongSwan 5.9.8 and kernel VTI
  behavior. This is a FlexVPN-concept analogue, not Cisco FlexVPN or IOS syntax.
- Certificate authentication, NAT traversal, scale, long-duration/adverse-WAN
  behavior, physical forwarding, and hardware crypto offload were not tested.
- Resource figures are maxima from the bounded active-load run, not an
  endurance or capacity benchmark.
