# Validation Record — `dmvpn-phase3-ipsec-capstone`

## Current status

Implementation, worker-owned static/image validation, and main-owned live
validation are complete. The same-reviewer read-only curriculum review is a
separate gate and is not claimed by this record.

The `lab-tutor` skill is unavailable in this environment. The student flow was
authored against `labs/AUTHORING.md` as the fallback contract. No tutor
validation or same-reviewer approval is claimed or implied.

## Environment

| Item | Exact value |
|------|-------------|
| Date and owner | 2026-08-23; implementation worker plus main live validator |
| Host | Ubuntu Linux, kernel `5.15.0-181-generic`, x86_64 |
| ContainerLab/Docker | ContainerLab `0.74.1` (`1866b3a2b`); Docker client/server `29.5.3` |
| VyOS | `vyos:local`, `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495`, amd64 |
| WAN bridge | `ops-lab:local`, `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, amd64 |
| PKI image | `dmvpn-pki:local`, `sha256:fa145e485b2cf9ef98052afcf3445df25d981fba8c31f94ddb68dc4ea527de3d`, amd64; Alpine 3.20; OpenSSL `3.3.7-r0` |
| Repository | branch `codex/networking-lab-remediation`; implementation not committed when live evidence was recorded |

## Exact validation contract

The grader fails closed on:

- exact six-node topology, image ownership, bridge membership, addresses,
  mGRE semantics, dummy service interfaces, and MTU 1400;
- exact live and saved learner-owned NHRP/OSPF/static/PKI/IPsec state;
- unexpected routing protocols, same-area service advertisements, PSKs, peers,
  selectors, IKE/CHILD SAs, XFRM state, or XFRM policy;
- CA and leaf constraints, usages, SAN/EKU/SKI/AKI, chain and key matching, and
  imported/source public fingerprint correlation without secret-bearing
  failure output;
- deterministic connection directions and exact AES-256/SHA-256/DH14/PFS14
  definitions;
- exactly 3 IKEv2 SAs, 3 CHILD SAs, 6 ESP states, 6 GRE/ESP transport peer
  policies, and 8 exact uid-0 socket bypass policies per router, for 14
  top-level policies total;
- three hub registrations/adjacencies, one summary/Type-2 LSA before traffic,
  and exactly two remote four-field `Type Prefix Via Identity` shortcut rows
  per spoke after traffic, with each `/24`, overlay next hop, and certificate
  FQDN correlated and no unexpected row;
- all six source-specific flows and adjacent exact outbound ESP counter
  increases;
- hub-first ESP followed by direct ESP with no raw GRE;
- a meaningful 1360-byte DF payload inside the enforced tunnel MTU.

The deliberate fault has a separate exact current-image shortcut predicate:
spoke1 exposes only `dynamic 192.168.2.0/24 172.16.0.12`, with no fourth
identity or extra row. Removing the live x509 peer removes the FQDN decoration,
not the preserved PKI. The healthy checker and seeder continue to require two
exact four-field x509-correlated rows per spoke.

## Main-owned clean-cycle evidence

Two complete pre-hardening deploy/destroy cycles and one additional
post-review clean validation deployment/destroy passed.

| Stage | Exact result |
|-------|--------------|
| Fresh baseline | In the post-review deployment: CA files 0, learned NHRP/OSPF/static/PKI/IPsec lines 0, up IKE rows 0, XFRM states 0, and capture processes 0. The earlier cycle 1 checker also rejected its unsolved baseline. |
| Interface precondition probe | The first hardened solution stopped before PKI because ContainerLab persists its exact dual-stack management `eth0` addresses in live and saved VyOS state. After the allowlist was derived independently from Docker network metadata, state remained CA files 0 and learned lines 0. |
| Native policy probe | The first solved hardened checker returned **239/8**: only the new policy assertions failed because strongSwan owns eight legitimate socket bypass policies per router. Protected capture and every other assertion passed. Modeling the exact 14-policy native inventory corrected the fixture, not the device. |
| Hardened solution | The final strict checker passed **247/0**. Every router had exactly 3 IKEv2 SAs, 3 CHILD SAs, 6 XFRM states, 6 GRE/ESP transport peer policies, and 8 exact native socket bypass policies. |
| Routing and identity | Before service traffic, each spoke had the sole external `/16`; after bounded traffic, all six service directions optimized and each healthy shortcut row had four exact fields including the remote x509 FQDN. |
| Packet and MTU proof | Correlated exact-state counters increased. Bridge capture showed protected hub-first then direct spoke forwarding as ESP with zero raw GRE. A 1360-byte DF payload crossed `tun0` MTU 1400. |
| Idempotence | Historical pre-hardening evidence: cycle 1 reapplied `solution.sh` twice and cycle 2 solved from zero at **243/0**, with PKI reuse and stable hashes. Post-review, a final repeated solution/checker returned **247/0**, again with all saved hashes stable and zero bridge capture residue. |
| Destroy | The two earlier destroys and the additional post-review destroy each cleaned fully. The final destroy left target containers 0, topology networks 0, lab processes 0, generated secret/capture files 0, private-key markers 0, and generated lab directories 0. |

## Focused healthy-state negatives

Every mutation was deliberately bounded, rejected by the strict checker, and
restored before proceeding.

| Mutation | Checker signature and restoration |
|----------|-----------------------------------|
| Extra live WAN address | **242/1**; removed |
| Rogue public certificate in the CA workspace | **242/1**; removed |
| Extra WAN bridge member | **241/2**; removed |
| Wrong saved crypto `remote-id` while live state stayed correct | **242/1**; original saved hash restored |
| Extra complete live x509 peer | **241/2**; removed |
| Swapped source certificate identity | **240/3**; CA workspace restored and revalidated |
| Post-review spoke1 saved+live `dum1 198.51.100.1/32` | **245/2**, only exact live/saved interface assertions; `solution.sh` returned 1 before mutation with `out-of-scope live interface pollution`; rejection preserved the polluted hash, and deletion restored the original hash and interface absence |
| Post-review spoke1 extra saved+live `eth0 198.51.100.2/32` | **245/2** and solution status 1 with the same fail-closed precondition; original hash/address state restored |
| Post-review hub live TCP/block XFRM policy, `203.0.113.1/32` to `198.51.100.1/32`, priority 100 | **246/1**, only the exact fourteen-total assertion; exact deletion restored total 14 |

## Deliberate fault and recovery

Historical pre-hardening evidence produced an armed-fault signature of
**212/31** and repaired to **243/0**. The post-review `break.sh` precheck passed
**247/0**. Both normal fault captures exited 0, left no residue, and preserved
saved hashes. The armed state had 0/0 target live peer lines, 11/11 saved target
peer lines, and an exact full-checker signature of **214/33**.

In both generations, the hub retained three Full OSPF neighbors and three
dynamic NHRP spoke registrations; target pair GRE/ESP policy counts were 0/0;
target and unrelated service pings passed; and PKI remained valid. Current
VyOS changed the target shortcut to
`dynamic 192.168.2.0/24 172.16.0.12` only while the live x509 peer was
unavailable. The direct capture proved raw GRE with readable inner ICMP, while
the unrelated spoke2↔spoke3 capture proved bidirectional ESP and no raw GRE.
Post-review repair returned **247/0**, preserved every saved hash, and left
zero capture residue.

## Transaction and capture lifecycle

Rollback was tested only after both target peers were absent:

- forced TERM returned 143, internally restored 247/0 health, preserved saved
  hashes, and left no capture process;
- forced INT under `env --default-signal=INT` returned 130 with the same full
  247/0 restoration, stable hashes, and cleanup;
- controlled ERR, induced by removing execute permission from
  `capture-leak.sh` only after both peers were absent, made `break.sh` return
  126 with Permission denied, internally restored 247/0 health, preserved
  hashes, restored the executable helper mode, and left no capture.

The earlier pre-hardening rollback tests restored 243/0; the 247/0 results
above are the final hardened repetitions.

There is no special exit-97 test hook and none is claimed.

Early main runs exposed a host-timeout `docker exec` orphan and then
BusyBox-timeout zombies in the bridge container. The final helper design uses
one container-local POSIX shell that owns, signals by recorded PID, and reaps
its exact `tcpdump` and `sleep` children. In the pre-hardening cycle it was
live-retested under healthy, ERR, INT, and TERM paths: historical 243/0 passed,
no new `tcpdump` or `timeout` process appeared, and no capture residue remained.
The cycle 2 bridge began and ended with zero such processes. Post-review, a
direct forced inner capture TERM made
the outer `capture-protected.sh` fail with status 1 and exact error
`hub-first capture exited with status 143`; no bridge `tcpdump` survived. This
proved that abnormal inner termination no longer counts as capture success.

## Active-load resources and Docker health

Six-direction 1360-byte payload sampling recorded these per-node peaks:

| Node | Peak memory | Approximate MiB | Peak CPU |
|------|------------:|----------------:|---------:|
| `hub` | 284262.40 KiB | 277.6 MiB | 2.22% |
| `spoke1` | 287436.80 KiB | 280.7 MiB | 4.03% |
| `spoke2` | 283136.00 KiB | 276.5 MiB | 3.80% |
| `spoke3` | 284569.60 KiB | 277.9 MiB | 4.41% |
| `br-wan` | 1024 KiB | 1.0 MiB | 0% |
| `ca` | 928 KiB | 0.9 MiB | 0% |

The aggregate of per-node memory maxima was approximately 1114.61 MiB
(1.088 GiB). Every node reported `OOMKilled=false` and restart count 0.

Docker marked all four VyOS containers unhealthy only because
`systemctl is-system-running` reported degraded after `atopacct.service` timed
out with `receive NETLINK family, errno -2`. Native routing and cryptographic
state remained functional. The strict checker passed the historical 243/0
contract during resource sampling and the final hardened 247/0 contract in the
post-review deployment. The bridge and CA images define no healthcheck.

## Worker-owned static and image checks

These checks were performed by the implementation worker and are distinct from
the main-owned live evidence above:

```text
bash -n (all capstone shell plus scripts/build-images.sh): PASS
ShellCheck -S warning (same scope): PASS
topology YAML parse and exact six-node inventory: PASS
docker build -t dmvpn-pki:local labs/dmvpn-phase3-ipsec-capstone/: PASS
image inspect: sha256:fa145e485b2cf9ef98052afcf3445df25d981fba8c31f94ddb68dc4ea527de3d; linux/amd64
package check: Alpine 3.20; openssl-3.3.7-r0; OpenSSL 3.3.7 7 Apr 2026: PASS
CA/4-leaf semantic, key-match, chain, SAN/EKU, SKI/AKI tests: PASS
idempotent CA/leaf reuse: PASS
router/FQDN allow-list rejection: PASS
partial-workspace refusal: PASS
0700 workspace and 0600 generated-file checks: PASS
```

The first image test used `apk info -v openssl`, whose current output is package
metadata rather than the installed version string. The assertion was corrected
to `apk list --installed openssl`. The first CA semantic test also assumed the
spaced `CN = value` display form; OpenSSL 3.3.7 emitted `CN=value`. The validator
accepts only those two formatting variants. The complete tests passed after
both corrections; neither weakens the required package or subject.

## Final main-owned repository gates

```text
bash -n: PASS
ShellCheck -S warning: PASS
python3 scripts/check-markdown-spacing.py: PASS
./scripts/check-docs-admonitions.sh: PASS
python3 scripts/lint-labs.py: PASS (143 labs, 54 images)
python3 scripts/validate-quizzes.py: PASS (44 quiz/key pairs)
git diff --check: PASS
mkdocs build --strict: PASS; only the existing Material MkDocs 2.0
informational warning and existing non-nav page notices were emitted
```

## Limitations, stress observation, and refresh

- After many artificial cycle 1 checker, negative, and fault runs plus repeated
  `clear ip nhrp shortcut/cache`, current VyOS eventually stopped regenerating
  all six transient shortcuts even though hub OSPF Full remained 3, NHRP
  registrations remained present, and 3/3 IKE/CHILD plus 6 XFRM states per
  router remained exact. This is a disclosed high-churn stress observation,
  not an ordinary-workflow result. Clean destroy/redeploy reset it; fresh cycle
  2 solution, fault, repair, TERM, INT, and ERR tests all passed.
- PKI generation is ephemeral and intentionally provides no revocation,
  renewal, OCSP, CA database, or production authority lifecycle.
- Static full-mesh peer configuration is O(N²) even though certificate
  credentials are O(N). No dynamic production profile is claimed.
- arm64, physical networks, hardware offload, dual hubs, large scale,
  long-duration operation, adverse WAN conditions, future VyOS images, and ESP
  tunnel mode remain unvalidated.
- The pinned Alpine/OpenSSL image must be reviewed monthly and before release;
  actionable critical advisories are triaged within 7 days and high advisories
  within 30 days under `docs/image-policy.md`.
- Direct router restart is not a supported persistence test; clean
  ContainerLab redeploy is required.
- No generated private key, certificate, capture, or ContainerLab artifact is
  intended for the repository.
