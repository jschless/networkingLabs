# ipsec-basics — Validation Record

## Status

The remediated lab passed the complete post-edit live workflow on two fresh,
clean deployments after a rejected development deployment exposed and fixed
three implementation defects. An additional accepted post-review deployment
then proved exact convergence and checker-backed lifecycle behavior after the
sole reviewer identified three further gaps. Healthy checks repeatedly
returned **114/0**; the deliberate fault repeatedly returned the stable,
causal **81/33** result; and repair restored **114/0**.

The same read-only reviewer completed follow-up, closed all three prior
findings, approved reviewer closure, and returned: `No actionable findings
remain`. The follow-up was read-only and did not deploy the lab. The lab tutor
was unavailable. Validation used `labs/AUTHORING.md` as the fallback authoring
contract and does not claim tutor validation.

## Environment

Validation ran on 2026-08-13 with this environment:

| Component | Observed value |
|-----------|----------------|
| Host | `x86_64`, Linux kernel `5.15.0-181-generic` |
| Docker | `29.5.3` |
| ContainerLab | `0.74.1` |
| `vyos:local` | `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495`, amd64, 2,264,851,359 bytes |
| VyOS software | Rolling release `2026.03.15-0031`, build commit `96ff51d3d2e559` |
| `ops-lab:local` | `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, amd64, 68,762,000 bytes |

Docker reported both VyOS containers as unhealthy because their packaged
health check expects `/boot/grub/grub.cfg`, which is absent in this container
execution model. This known health-check quirk did not prevent native VyOS
configuration, IKE/child SA creation, XFRM installation, protected traffic,
fault injection, or recovery. Every container reported `OOMKilled=false`.

## Rejected development deployment and fixes

The first post-edit deployment was used as a development run and was rejected
from the final clean-deployment evidence after it exposed three concrete
defects:

1. The bound `/bin/vbash` helpers enabled shell `errexit` after sourcing the
   VyOS script template. VyOS's internal `(( idx++ ))` then returned status 1
   from an initial zero and aborted the first configuration command before any
   IPsec mutation. The strict option line was removed from all bound helpers,
   matching the repository-safe VyOS pattern.
2. The first healthy checker returned **112/2** solely because the NAT-T
   assertion expected a `NAT-T:` label in each data row. The real table places
   `no` in the NAT-T column of the full IKE row. The assertion was changed to
   match that exact semantic row, after which the same healthy state returned
   **114/0**.
3. The first deliberate break refused before mutation because its saved-state
   guard expected `hash sha256`, while VyOS serialized `hash "sha256"`. The
   break and repair guards were changed to accept exact optional quoting while
   continuing to reject quoted or unquoted `sha512` saved state.

The rejected deployment remained healthy after the guarded failure. Once the
fixes were present, the full workflow was repeated on two fresh accepted
deployments.

## Reviewer findings and remediation

The sole read-only reviewer identified three lifecycle-contract gaps:

1. The solution helpers added the required commands without first removing
   the existing learned subtree, so extra learner-created proposals, peers, or
   selectors could remain even though the helper reported success.
2. The deliberate fault's public-underlay postcondition checked only
   `gw-a`'s near next hop, not the current far peer endpoint claimed by the
   learner workflow.
3. The break and repair saved-state guards inspected only one hash leaf, so a
   polluted saved definition could escape their success criteria.

The fixes changed both apply helpers to delete and rebuild the complete
`vpn ipsec` subtree before committing and saving. `solution.sh` now requires a
full checker pass before success. `break.sh` requires a full **114/0**
precondition and verifies far-peer public reachability from `gw-a` to
`203.0.113.6` and from `gw-b` to `203.0.113.1`. Transactional rollback and
normal repair now require both an unchanged saved checksum and a full checker
pass before reporting success.

## Fresh baseline and clear-text containment

Both final deployments started with exactly five nodes and the intended image
mapping: native `vyos:local` on `gw-a` and `gw-b`, and `ops-lab:local` on both
hosts and the transit node. Exact addresses, host defaults, gateway static
routes, and the transit node's five-rule FORWARD policy were present. The
FORWARD default was `DROP`, with the rules in the intended deterministic
order.

Neither startup configuration contained `vpn ipsec` state. Initial IKE,
child-SA, and XFRM tables were empty. Near and far public WAN reachability
passed from both gateways, while private host traffic failed in both
directions. The transit private-source drop counter reached four packets,
proving that the explicit remote-private routes did not permit the selected
flow to cross in clear text.

## Clean learner workflow

The complete mirrored solution produced the following exact healthy state on
each accepted fresh deployment:

- exactly one IKE SA and one child SA on each gateway;
- IKEv2 with `AES_CBC_256`, `HMAC_SHA2_256_128`, `MODP_2048`, and NAT-T `no`;
- child names `GW-B-tunnel-1` on `gw-a` and `GW-A-tunnel-1` on `gw-b`;
- child encryption/integrity
  `AES_CBC_256/HMAC_SHA2_256_128`;
- exact reciprocal WAN identities and `192.168.1.0/24` ↔
  `192.168.2.0/24` selectors;
- three directional XFRM policies and two ESP states per gateway;
- positive protected counters in both directions;
- successful private host traffic in both directions; and
- exact matching complete live and saved learned definitions without the
  checker printing the shared secret.

Solution-helper timings were:

| Context | Run | Convergence |
|---------|-----|-------------|
| Development deployment after helper fix | First application | 9.40 seconds |
| Development deployment after helper fix | Immediate idempotent application | 6.27 seconds |
| Final fresh deployment 1 | Application | 9.51 seconds |
| Final fresh deployment 2 | Application | 9.97 seconds |

The checker returned **114/0** repeatedly in the development workflow, both
final deployments, after every normal repair, after forced transactional
rollback, and under active protected traffic.

The bounded capture repeatedly showed bidirectional outer
`203.0.113.1` ↔ `203.0.113.6` ESP and no private address or readable inner
ICMP. Capture cleanup removed its temporary file and left no capture process.

## Focused negative checks

Two reversible focused negatives proved that the checker isolates stable
configuration invariants rather than only grading the resulting traffic:

| Negative | Result | Only failed assertion | Recovery |
|----------|--------|-----------------------|----------|
| Change only `gw-b`'s saved ESP hash | **113/1** | `gw-b saved learned state matches the complete healthy definition` | Restored the exact original saved SHA; **114/0** |
| Remove only `gw-a`'s live remote-private route | **113/1** | `gw-a has a routed policy-selector path` | Restored the route; **114/0** |

## Deliberate fault and recovery

Three normal fault runs changed only `gw-b`'s live IKE hash to `sha512`, left
the saved `sha256` definition and saved-file hash unchanged, and reset the
initiating peer. Each run preserved public reachability while removing both
up SAs, all relevant XFRM state, and private forwarding. `gw-a` logged
`NO_PROPOSAL_CHOSEN`, and the checker produced the identical causal
**81/33** result.

| Run | Break convergence | Fault checker | Repair convergence | Recovered checker |
|-----|-------------------|---------------|--------------------|-------------------|
| Development 1 | 9.05 seconds | **81/33** | 4.36 seconds | **114/0** |
| Development 2 | 9.17 seconds | **81/33** | 3.93 seconds | **114/0** |
| Final fresh deployment 1 | 8.81 seconds | **81/33** | 4.05 seconds | **114/0** |

An immediate second repair completed in 2.80 seconds and retained **114/0**,
proving repair idempotence. Every recovered state also reproduced the bounded
outer-only ESP capture.

Transactional interruption was tested after the exact live `sha512` mutation
was observed. Sending `TERM` caused `break.sh` to report rollback, exit 143,
restore live `sha256` and full service, preserve the unchanged saved state,
and return the lab to **114/0**.

## Post-review live validation

An additional fresh deployment completed in 24.39 seconds with maximum
command RSS of 42,296 KiB. This deployment specifically exercised the
reviewer-requested behavior changes; it supplements rather than replaces the
two earlier accepted final deployments.

First, `gw-a` was deliberately polluted in both live and saved state with an
extra IKE group named `EXTRA`, while `gw-b` was polluted in both live and saved
state with an extra ESP group of the same name. `solution.sh` deleted and
rebuilt both complete learned subtrees, removed both extras from live and
saved configuration, and ran an embedded **114/0** checker before reporting
success. The run completed in 22.75 seconds with maximum command RSS of
30,128 KiB. An immediate idempotent run again embedded **114/0**, completing
in 20.47 seconds with maximum command RSS of 30,236 KiB.

Next, `gw-b` was polluted again in both live and saved state with the extra
ESP group. The break helper's exact precondition checker returned **112/2**,
with only the `gw-b` live and saved complete-definition assertions failing.
`break.sh` returned 1 before introducing `sha512`. The exact-convergence
solution removed the pollution and embedded **114/0**.

From that clean state, the supported deliberate break embedded its **114/0**
precheck, verified `gw-a` → `203.0.113.6` and `gw-b` → `203.0.113.1`, and
converged in 23.05 seconds with maximum command RSS of 30,148 KiB. An
independent checker retained the expected **81/33** fault result, and the
saved checksum remained unchanged. Repair completed in 17.54 seconds with
maximum command RSS of 30,188 KiB, embedded **114/0**, and was followed by a
passing bounded ESP capture.

Forced `TERM` was repeated after live `sha512` was observed. `break.sh` exited
143; rollback embedded **114/0** and explicitly reported that it restored the
live hash, unchanged saved checksum, and full service. An independent checker
then returned **114/0**, and the bounded capture passed again.

The post-review deployment was cleanly destroyed in 1.40 seconds with maximum
command RSS of 40,312 KiB. No target container, generated lab directory, or
temporary capture file remained.

## Active resources

A bidirectional protected flood ran while five samples were collected:

| Node | Observed memory range |
|------|-----------------------|
| `gw-a` | 266.6–267.4 MiB |
| `gw-b` | 266.5–267.3 MiB |
| `host-a` | 636 KiB |
| `host-b` | 636 KiB |
| `internet` | 1.086 MiB |

Maximum observed aggregate memory was approximately 537.03 MiB, and maximum
observed CPU was 0.63%. All nodes retained `OOMKilled=false`. The checker
returned **114/0** and the encrypted capture passed under load. No flood
process remained afterward. These short samples are point-in-time
observations, not capacity guarantees.

## Accepted final deployment cycles and cleanup

| Cycle | Deploy time | Deploy max RSS | Workflow | Destroy time | Destroy max RSS |
|-------|-------------|----------------|----------|--------------|-----------------|
| Final 1 | 25.86 seconds | 42,488 KiB | Baseline; solution; **114/0**; capture; break **81/33**; repair **114/0** | 1.46 seconds | 40,276 KiB |
| Final 2 | 26.60 seconds | 42,204 KiB | Baseline; solution; **114/0**; capture | 1.38 seconds | 40,608 KiB |

After each final destroy, no target container, generated lab directory,
temporary capture file, or leaked capture/flood process remained. The final
target-lab runtime state was clean.

## Repository gates and review

The following gates passed:

- target `bash -n`, ShellCheck at warning severity, and YAML parsing;
- markdown block spacing and documentation-admonition checks;
- lab lint: 143 labs and 53 distinct images;
- quiz validation: 44 quizzes;
- `git diff --check`; and
- `mkdocs build --strict`.

The strict documentation build emitted only the upstream Material for MkDocs
2.0 warning and existing navigation information; it completed successfully.

The lab tutor was unavailable, and `labs/AUTHORING.md` was used as the
fallback. The sole read-only reviewer pass produced the three findings above,
and the fixes have post-review live evidence. The same reviewer completed a
read-only, no-deployment follow-up, closed all three findings, approved
reviewer closure, and returned: `No actionable findings remain`.

## Validation limits

Live validation did not cover arm64, physical VyOS appliances, hardware
cryptographic acceleration or offload, NAT-T, certificate authentication,
long-duration rekey, induced packet loss, or scale. The Docker health status
remained affected by the documented missing-`grub.cfg` container quirk even
while the validated native mechanisms were healthy. Resource measurements are
short point-in-time observations rather than capacity or stability
guarantees.
