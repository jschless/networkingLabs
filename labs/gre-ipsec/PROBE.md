# gre-ipsec — Pre-implementation Probe

## Scope and method

This record preserves the read-only analyst findings and main-orchestrator
live probes that selected the remediation design. It is not post-edit
validation; those results belong in `VALIDATION.md`.

The lab tutor was unavailable. The analyst and implementation use
`labs/AUTHORING.md` as the fallback authoring contract and do not claim tutor
validation.

## Analyst findings

- Classification: **Build**. Learners build native VyOS transport-mode IPsec
  around a prerequisite GRE overlay.
- Explicit prerequisites: `gre-basics` and `ipsec-basics`.
- Critical roles: `gw-a` and `gw-b` on native `vyos:local`; there is no
  critical-role Linux exception.
- Incidental roles: `host-a`, `host-b`, and `internet`. Their required
  addressing, forwarding, ping, and capture functions fit the pinned
  `ops-lab:local` image without FRR or cEOS.
- The original abbreviated preamble, incomplete mirrored answer, unbounded
  capture commands, answer-exposed fault, stale strongSwan scripts, broad
  factual claims, and six-check grader did not meet the practice-lab contract.
- The original claim that a one-sided IPsec failure necessarily failed closed
  was identified as a high-risk assertion requiring a causal live probe.

## Platform and prerequisite probe

The original native VyOS deployment had reciprocal `tun0` GRE interfaces and
static remote-LAN routes. Far-WAN, tunnel-endpoint, and host-to-host traffic
worked before IPsec was configured. A bounded-equivalent transit observation
using numeric BPF protocols showed outer
`203.0.113.1` ↔ `203.0.113.6` GRE and readable inner
`192.168.1.10` ↔ `192.168.2.10` ICMP. Symbolic `gre or esp` filtering was not
accepted by the original cEOS observer; numeric `ip proto 47` and
`ip proto 50` were therefore selected for portable helpers.

The existing GRE startup scaffold was retained because it is prerequisite
state rather than the learned IPsec answer:

- `gw-a`: `tun0` `172.16.0.1/30`, source `203.0.113.1`, remote
  `203.0.113.6`, and `192.168.2.0/24` via `172.16.0.2`;
- `gw-b`: `tun0` `172.16.0.2/30`, source `203.0.113.6`, remote
  `203.0.113.1`, and `192.168.1.0/24` via `172.16.0.1`.

## Healthy native mechanism evidence

The main probe applied matching native VyOS configuration with `gw-b` passive
(`connection-type none`) and `gw-a` initiating. The accepted healthy state
was:

- IKEv2 with AES-256, SHA-256, and DH group 14;
- ESP transport mode with AES-256 and SHA-256;
- one up IKE SA and one up child SA per gateway;
- IKE runtime algorithms `AES_CBC_256`, `HMAC_SHA2_256_128`, and
  `MODP_2048`, with NAT-T `no`;
- child algorithms `AES_CBC_256/HMAC_SHA2_256_128`;
- reciprocal public-WAN `/32[gre]` connection selectors;
- exactly two relevant protocol-GRE XFRM policies and two directional XFRM
  states per gateway, all in transport mode;
- successful bidirectional private-LAN traffic;
- a transit capture containing only bidirectional public ESP; and
- a `tun0` capture containing readable private ICMP above the transform.

Transport mode retains the existing public/WAN IP header and encrypts the GRE
header plus its encapsulated inner packet. It avoids the additional outer IPv4
header that IPsec tunnel mode would add; no universal overhead or MTU number is
claimed because ESP options and NAT-T can change it.

## Causal confidentiality-failure probe

The main probe changed only `gw-b`'s **live** ESP hash from `sha256` to
`sha512`, then reset only `gw-a`'s tunnel-1 child. This disproved the original
fail-closed claim:

- exactly one IKE SA remained up on each gateway;
- both child SAs disappeared;
- relevant GRE XFRM policies disappeared;
- far-public reachability remained healthy;
- host-to-host traffic still succeeded in both directions;
- the transit path again exposed raw GRE and readable private ICMP; and
- `gw-a` logged `NO_PROPOSAL_CHOSEN`, `no CHILD_SA built`, and
  `keeping IKE_SA`.

Without an installed XFRM policy owning protocol 47, the preconfigured GRE
overlay fell back to clear text. The stable lesson is therefore that green
connectivity and an up IKE SA do not prove confidentiality. This became the
opaque transactional Break-It scenario. Restoring only the live ESP hash and
resetting the child recovered protected forwarding.

## Risks for post-edit validation

- Exact output formatting, SA cardinalities, XFRM selector rows, policy/state
  counts, and counter syntax must be verified on a fresh edited deployment.
- Each bounded capture helper must be tested for positive predicates, timeout
  behavior, process cleanup, and temporary-file cleanup.
- The fault helper must prove all underlay, IKE, child, XFRM, forwarding, log,
  leak, and saved-checksum postconditions before reporting success.
- ERR/INT/TERM rollback must be interrupted after mutation and must restore a
  full checker pass without changing saved state.
- Solution convergence from polluted live/saved state, repair idempotence,
  focused negatives, active-load resources, clean destroy, repository gates,
  and read-only review remain post-edit work.
- The probe does not validate arm64, physical appliances, hardware crypto,
  NAT-T, rekey duration, induced loss, or scale.
