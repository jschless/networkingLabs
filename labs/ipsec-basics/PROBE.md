# ipsec-basics — Pre-implementation Probe

## Scope and method

This file records the read-only analyst findings and the main-agent platform
and mechanism probes that determined the remediation design. It is not the
post-edit validation record; final learner-workflow results belong in
`VALIDATION.md`.

The lab tutor was unavailable. The analyst and implementation therefore use
`labs/AUTHORING.md` as the authoring contract and do not claim tutor
validation.

## Analyst findings

- Classification: **Build**. The learned objective is native VyOS
  policy-based IKEv2/ESP, not Linux strongSwan configuration.
- Critical roles: `gw-a` and `gw-b`. They must remain `vyos:local` because
  learners configure and diagnose the VyOS IPsec model directly.
- Incidental roles: `host-a`, `host-b`, and `internet`. They need only basic
  addressing, routing, filtering, ping, and capture tools, so
  `ops-lab:local` is the appropriate pinned image.
- No critical-role Linux/FRR exception applies.
- The original abbreviated preamble, incomplete task anatomy, open fault
  prescription, route/selector conflation, answer-adjacent stale gateway
  setup scripts, and six broad checks were not sufficient for a rigorous
  practice lab.
- The original `ipsec-lab:local` image is unnecessary here, but its Dockerfile
  remains the documented build context for `flexvpn-basics`; deleting it would
  break a separate lab.

## Native VyOS probe

The pre-edit probe used the locally available `vyos:local` image. `show
version` identified VyOS rolling release `2026.03.15-0031` on amd64; the local
image ID began with `sha256:74835`. The final validation record must capture
the complete immutable ID rather than infer it from this abbreviated note.

The README's IKEv2, ESP, PSK, identity, peer, and selector syntax was accepted
by that release. The valid connection-type values exposed by the CLI were
`initiate`, `trap`, and `none`; `respond` was not valid. Using `initiate` on
`gw-a` and `none` on `gw-b` produced one IKE SA and one child SA instead of
duplicate initiation behavior.

## Routing and clear-text containment probe

The design retains explicit base routes:

- `gw-a`: `192.168.2.0/24` via `203.0.113.2`
- `gw-b`: `192.168.1.0/24` via `203.0.113.5`

These routes give the kernel a forwarding decision; traffic selectors then
intercept the selected flow. The design does not claim that selectors create
routing. The incidental transit installs deterministic FORWARD drops for both
private sources and private destinations while explicitly permitting the
public underlay and ESP. The before-state can therefore exercise route lookup
without allowing clear-text private traffic to cross.

## Healthy mechanism evidence

The main probe observed the following native state after matching
configuration:

- one up IKE SA on each gateway;
- IKEv2 with `AES_CBC_256`, `HMAC_SHA2_256_128`, and `MODP_2048`;
- NAT-T `no`;
- one child, `GW-B-tunnel-1` or `GW-A-tunnel-1`, using
  `AES_CBC_256/HMAC_SHA2_256_128`;
- exact reciprocal `192.168.1.0/24` and `192.168.2.0/24` traffic selectors;
- usable `show vpn ipsec connections`, `show vpn ipsec policy`, and Linux
  `ip -s xfrm` views;
- bidirectional host traffic incrementing protected counters; and
- a bounded `internet eth1` capture containing only outer
  `203.0.113.1` ↔ `203.0.113.6` ESP, without readable private or ICMP fields.

## Deliberate fault probe

A live-only change of `gw-b` proposal 10's IKE hash to `sha512`, followed by
an explicit `reset vpn ipsec site-to-site peer GW-B` on `gw-a`, produced a
stable causal failure:

- public WAN reachability remained healthy;
- no up IKE SA remained;
- no up child SA remained;
- private-LAN traffic failed; and
- `gw-a` logged `NO_PROPOSAL_CHOSEN`.

Restoring only the live hash to `sha256` and resetting the initiator recovered
the complete healthy state. The broken state was not saved. This became the
opaque, transactional Break-It lifecycle.

## Risks for final validation

- Exact output layout and XFRM policy counts must be checked on a fresh edited
  deployment; the checker must be adjusted if formatting differs while
  preserving exact semantic assertions.
- The fault helper's ERR/INT/TERM rollback must be interrupted after mutation
  and proven to restore both service and the unchanged saved hash.
- Transit rule ordering must be verified, not merely rule presence.
- The solution and repair helpers need repeated idempotence tests.
- Bounded capture cleanup, active-load resource samples, clean destroy, and
  focused negative tests remain post-edit work.
- The probe was amd64-only and software/container-only. It did not validate
  arm64, physical appliances, hardware crypto offload, NAT-T, certificate
  authentication, long-duration rekey, or scale.
