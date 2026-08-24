# Feature Probe Record — `dmvpn-phase3-ipsec-capstone`

## Scope and decision

- **Feature and learning objective:** native VyOS DMVPN Phase 3 summary/shortcut
  behavior protected by x509-authenticated IKEv2 and GRE-scoped ESP transport.
- **Decision:** go on four critical `vyos:local` routers; keep only the Ethernet
  bridge as incidental `ops-lab:local`; replace the legacy CA role with a new
  purpose-built `dmvpn-pki:local` image.
- **Reason and fidelity statement:** the local VyOS image accepted the exact PKI,
  x509 identity, deterministic peer, transport-mode GRE selector, NHRP, and OSPF
  syntax and produced native strongSwan/XFRM state. No routing or cryptographic
  behavior is mocked.
- **Owner and date:** curriculum remediation, 2026-08-23.

## Environment

| Item | Exact value |
|------|-------------|
| Host | Ubuntu Linux, kernel `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | client/server `29.5.3` |
| VyOS | `vyos:local`, image ID `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495`, amd64 |
| Incidental bridge | `ops-lab:local`, image ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, amd64 |
| CA image | `dmvpn-pki:local`, image ID `sha256:fa145e485b2cf9ef98052afcf3445df25d981fba8c31f94ddb68dc4ea527de3d`, amd64; base `alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc`; OpenSSL `3.3.7-r0` |

## Analyst and legacy findings

The read-only curriculum/platform pass classified this as a **Capstone** and
found the legacy workflow unsafe or instructionally incorrect:

- the CA role used `frr-lab:local`, but the deployed local image had no
  `openssl` executable; issuance could not start;
- the README advertised spoke service `/24`s into the shared OSPF area, which
  contradicts the validated sole-summary Phase 3 design;
- loopback service addressing, a hub blackhole-only summary, and claims about
  NHRP `/24` installation did not match current-image behavior;
- the 15 checks accepted any one peer/SA/mapping and never distinguished ESP
  from raw GRE;
- the fault exposed its own cause and allowed mutually exclusive outcomes;
- identity, proposal, selector, saved-state, rogue-state, source-specific flow,
  and key-chain checks were missing;
- unique pairwise PSK O(N²) scaling was incorrectly stated as the only PSK
  model, and credential scaling was conflated with static peer scaling;
- a CRL challenge was unsupported because the scripts maintained no CA
  database or revocation workflow.

## Smallest load-bearing tests

### Phase 3 control plane

The accepted control plane is inherited from the clean live
`dmvpn-phase3` probe/validation:

- hub exact service `/24` statics use overlay next hops `.11`, `.12`, `.13`;
- the hub redistributes static and applies external
  `summary-address 192.168.0.0/16`;
- spokes advertise overlay `/32`s only;
- before traffic, each spoke has exactly one selected external service `/16`
  through the hub and one Type-2 LSA originated by `10.0.0.1`, with no remote
  service `/24` or `/32`;
- after traffic, current VyOS correlates the remote service host to its NBMA;
  in this x509 capstone the `Type Prefix Via Identity` table shows the exact
  four-field row
  `dynamic 192.168.N.0/24 172.16.0.1N spokeN.dmvpn.lab`, and the router selects
  an NHRP host `/32` with a direct `tun0` FIB.

### x509 peer and XFRM syntax

The main probe imported generated CA/leaf/key material and accepted the exact
current VyOS syntax for:

- IKEv2 AES-256/SHA-256/DH14, lifetime, and restart DPD;
- ESP AES-256/SHA-256 transport, PFS14, and lifetime;
- x509 local/remote FQDN identities, local certificate, and CA binding;
- named static peers with exact local/remote WAN addresses and `protocol gre`;
- one-sided initiation ordered `hub < spoke1 < spoke2 < spoke3`.

After a clean strongSwan load, every router had exactly three established IKE
SAs, three up CHILD SAs, six ESP XFRM states, six relevant GRE/ESP transport
policies, and eight native uid-0 socket bypass policies: two input and two
output for each of IPv4 and IPv6, making 14 top-level policies total. This
rejected the duplicate-SA risk of allowing both endpoints to initiate.

### Post-review native inventory probes

A fresh post-review baseline had CA files 0, learned protocol/PKI/IPsec lines
0, up IKE rows 0, XFRM states 0, and capture processes 0. The hardened solution
first stopped safely before PKI because ContainerLab injects its exact
dual-stack `eth0` management addresses into both live and saved VyOS state.
Deriving only those two allowed addresses from independent Docker network
metadata preserved the complete configured-interface negative without
confusing management state with learner pollution. State remained at CA files
0 and learned lines 0 after that safe rejection.

The first solved run then returned **239/8** only because current strongSwan
adds the eight native socket bypasses described above. Every other assertion,
including protected capture, passed. After the checker modeled all 14 native
policies exactly, it returned **247/0**. Focused post-review negatives rejected
saved+live `dum1 198.51.100.1/32` and an extra saved+live
`eth0 198.51.100.2/32` at **245/2** each; the solution precondition returned 1
before changing their polluted saved hashes. A live rogue TCP/block XFRM
policy from `203.0.113.1/32` to `198.51.100.1/32` was rejected at **246/1**,
and exact deletion restored the 14-policy inventory.

### Packet ownership and failure boundary

After clearing transient spoke1 shortcut state, a service flow from spoke1 to
spoke2 was observed first as ESP `10.0.0.11 → 10.0.0.1`. After shortcut
resolution, it was ESP `10.0.0.11 → 10.0.0.12`. Healthy capture contained zero
raw GRE.

The probe then removed only the live spoke1↔spoke2 peer branches at both ends.
Saved configuration hashes remained unchanged; PKI, hub registrations, all
three hub OSPF adjacencies, summary reachability, and the unrelated
spoke2↔spoke3 encrypted path survived. The direct target path remained
reachable with the exact three-field shortcut row
`dynamic 192.168.2.0/24 172.16.0.12`, but its healthy fourth-field x509 FQDN
decoration was absent because the live peer was unavailable to supply the
identity. The path leaked raw GRE whose inner ICMP was readable. This
fault-state observation does not weaken the healthy four-field contract.
Restoring only the two live branches returned the exact 3 IKE / 3 CHILD / 6
ESP-state / 6 GRE-peer-policy state plus all eight native socket bypasses.

The hardened fault run began with a **247/0** precheck. Both capture helpers
exited 0 with no residue; target live peer lines became 0/0 while saved lines
remained 11/11, and the armed full-checker signature was **214/33**. Repair
returned **247/0** with stable saved hashes. TERM 143, INT 130, and controlled
ERR 126 each occurred only after both live peers were absent and each
internally restored 247/0 health, stable hashes, and zero capture residue. A
direct forced inner TERM was also rejected by the outer capture helper with
status 1 and left no `tcpdump`.

### MTU boundary

With the image's original tunnel MTU 1476, protected DF payloads 1400 and 1404
bytes passed while 1408 bytes and larger returned message-too-long. The lab
therefore enforces `tun0` MTU 1400 and validates a meaningful 1360-byte DF ICMP
payload safely within that interface contract. It does not claim a universal
underlay PMTU from the one local probe.

## Rejected designs

- **Legacy FRR CA:** `openssl` absent in the live local image; a routing image
  is also unnecessary for intrinsic PKI scaffolding.
- **Same-area service advertisements:** create per-spoke specifics and defeat
  the sole-summary/O(1) service-route observation.
- **Blackhole summary as the only hub service ownership:** does not point real
  service destinations at their registered overlays.
- **Bidirectional initiation:** can race duplicate IKE/CHILD SAs.
- **Capture on one interface or a fixed packet count:** can miss the chosen
  bridge leg or exit on duplicated `any` records.
- **Group-PSK omission:** pairwise PSKs are O(N²), but a reusable group secret
  exists and must be discussed with its weaker isolation/rotation properties.

## Cleanup and repeatability

The probe restored the minimal live pair definitions, exact 3 IKE / 3 CHILD /
6 ESP states / 6 GRE peer policies, and all eight native socket bypasses before
its disposable topology was removed. Subsequent main validation
completed two clean deploy/destroy cycles, repeated fresh and idempotent
solutions at the historical pre-hardening **243/0**, exercised fault/repair and
transactional signal/error rollback, and left no target container, network,
capture/helper process, or generated PKI/capture artifact after either
destroy. An additional post-review deployment repeated solution/checker at
**247/0** with stable hashes, then destroyed to 0 containers, topology
networks, lab processes, generated secret/capture files, private-key markers,
and generated lab directories.

## Unsupported behavior and boundaries

- No CRL, OCSP, CA database, automated renewal, or production revocation claim.
- No dynamic/responder profile, dual-hub, spoke scale, adverse-WAN,
  long-duration, or hardware-offload validation.
- No ESP tunnel-mode comparison was validated for this capstone.
- Current service-host mapping/shortcut formatting and VyOS health quirks are
  version-qualified, not promises for a future image.
- Under many artificial checker, negative, fault, and repeated shortcut/cache
  clear operations, current VyOS eventually stopped regenerating every
  transient shortcut despite intact routing registration and crypto state. A
  clean redeploy reset it, and the complete ordinary workflow then passed. This
  high-churn stress observation is not generalized to normal learner use.
- Direct `docker restart` is outside the persistence contract because
  ContainerLab-injected interfaces can disappear from restarted namespaces.
