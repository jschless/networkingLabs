# Validation Record — `copp-basics`

## Implementation and image evidence

| Item | Result |
|---|---|
| Date/owner | 2026-08-07; Codex implementation and main live-validation passes |
| Corrected cached image build | `docker build -t copp-lab:local labs/copp-basics/` passed in 0.26 seconds; command max RSS 52,844 KiB |
| Corrected image identity | `sha256:643136a822877f72eae64f1c0808a873910fc6d371bebda2bf21f5c16063284f`; amd64; 197,231,555 bytes; idle CMD |
| External base | FRR 10.5.0 / Alpine 3.22.2 at digest `sha256:fc7f887ab4d8da06f481a4f8d59afded88b3c5823f03610a7e808f7eba45eeea` |
| Bounded feature probe | 20 local echo requests: 4 accepted, 16 dropped by the 2/second, burst-4 class |

The image refresh pins busybox `1.37.0-r20`, c-ares `1.34.8-r0`, iptables
`1.8.11-r1`, musl `1.2.5-r12`, and zlib `1.3.2-r0` in one `apk add --no-cache`
layer. These close the fix-available findings identified in the inherited base
inventory.

## Advisory review

The main pass rescanned all 72 installed packages in corrected image
`sha256:643136a822877f72eae64f1c0808a873910fc6d371bebda2bf21f5c16063284f`
against the official Alpine v3.22
[main](https://secdb.alpinelinux.org/v3.22/main.json) and
[community](https://secdb.alpinelinux.org/v3.22/community.json) security
databases. It found 0 packages with an available v3.22 security fix and 0 CVEs
in that fix-available set.

This is a fix-availability scan, not proof of zero vulnerability or zero
risk. The image remains a disposable lab dependency with bounded capabilities
and controlled traffic. Owner: repository maintainers. Next review:
2026-09-07, or earlier for a curriculum release or actionable advisory.

## Static validation

The implementation pass covers:

- pinned Dockerfile and exact three-node `copp-lab:local` topology;
- FRR addressing, eBGP, point-to-point OSPF, and reciprocal route scaffold;
- a five-task AUTHORING-format build workflow with hidden solutions;
- exact classifier, rate/drop, saved-state, and bounded runtime assertions;
- an idempotent opaque break that changes only active attachment state; and
- an idempotent repair that restores exactly one first-position attachment.

The implementation gates passed:

```text
bash syntax for lab scripts                    PASS
ShellCheck -S warning for lab scripts          PASS
python3 scripts/check-markdown-spacing.py      PASS
./scripts/check-docs-admonitions.sh            PASS
python3 scripts/lint-labs.py                    PASS (143 labs, 53 images)
git diff --check                               PASS
```

`lab-tutor` is unavailable in this environment; no tutor-validation claim is
made.

## Main live validation

The first target deploy did **not** complete. The inherited image command and
the topology setup both started/loaded FRR; r3 blocked on the duplicate
`vtysh -b` path. The main pass interrupted the deploy after 80 seconds and
destroyed it fully. This is negative discovery evidence, not a successful
deployment.

The corrected image uses an idle command, while the bounded setup script is
the sole FRR startup/config owner. The corrected clean deploy passed in 3.53
seconds with command max RSS 41,104 KiB.

### Clean build and policy walk

The corrected deployment had exactly r1, r2, and r3 on `copp-lab:local`, with
the documented loopback and link addresses. Both eBGP views were Established,
both OSPF views were Full, and sourced loopback pings succeeded in both
directions through r2.

The exact README policy solution was executed. A bounded 20-request burst from
r3 to r2 produced 4 ICMP accepts and 16 drops. A subsequent r1-to-r3 transit
probe delivered 3 of 3 packets and did not change either ICMP class counter,
proving the `INPUT` versus `FORWARD` boundary. The healthy checker passed all
14 assertions twice.

### Break, repair, and atomic negatives

Two consecutive `break.sh` runs each preserved routing, definitions, and the
saved healthy policy. The checker returned exactly 13 passed and 1 failed;
only `bounded local-versus-transit enforcement` failed. Two consecutive
`solution.sh` runs restored the single active attachment, after which the
checker passed 14 of 14 twice.

Three focused negative tests independently exercised checker atomicity:

| Mutation | Exact checker result | Sole failed assertion |
|---|---:|---|
| Wrong ICMP rate | 13 passed, 1 failed | `exact ICMP policer definition` |
| Missing BGP source-port dispatch | 13 passed, 1 failed | `exact classifier dispatch` |
| Corrupted saved reference | 13 passed, 1 failed | `saved policy matches the healthy reference` |

Each mutation was restored before the next. The final checker returned 14
passed and 0 failed.

### Resources, repeatability, and cleanup

The point-in-time memory sample was 26.08 MiB for r1, 26.85 MiB for r2, and
25.88 MiB for r3, approximately 78.81 MiB total. This is a point sample, not
peak or steady-state profiling.

The first corrected destroy removed every lab container, the `clab` Docker
network, and the generated lab directory. A second clean deploy repeated the
policy walk and passed 14 of 14; its clean destroy again removed all three
artifact classes.

Main live validation and read-only reviewer closure are complete. `lab-tutor`
is unavailable in this environment, so no tutor-validation claim is made.

## Reviewer closure

The first read-only review produced three findings. The implementation now:

- requires the saved policy to contain the exact four custom-chain
  declarations and pass a non-mutating `iptables-restore --test`, while
  retaining the exact saved rules and first `INPUT` attachment in the same
  single assertion;
- compares all four learned live definitions exactly but reports only a
  generic mismatch instead of printing the answer; and
- records the complete immutable external FRR base reference in the README
  and shared image inventory.

The checker still contains 14 assertions by inspection. The live counts above
predate these reviewer changes. Focused revalidation passed the first
break/check/repair cycle: the broken checker returned exactly 13 passed and 1
failed, and the repair validated. During the second cycle, a transient
post-mutation guard failure made `break.sh` abort after it had removed the
`INPUT` jump. BGP, OSPF, transit, all custom chains, and the saved reference
remained healthy, but the live `INPUT` chain contained only its ACCEPT policy.

The injector is now transaction-safe. It arms rollback before changing
`INPUT`; any subsequent command, validation, interrupt, or termination failure
normalizes the live policy path to exactly one first-position `INPUT` to
`COPP` jump before aborting. Rollback changes no saved file or other rule.
Successful injections remain idempotent and intentionally leave the jump
absent.

### Targeted reviewer-fix revalidation

A corrected clean deployment and exact policy build ended with all 14 checker
assertions passing. The following focused tests then passed:

- Removing only the saved `:COPP-OSPF - [0:0]` declaration returned exactly
  13 passed and 1 failed; only `saved policy matches the healthy reference`
  failed. The generic failure output exposed neither an `-A COPP` rule nor a
  `--limit` value. Restoring the declaration returned the checker to 14 of 14.
- Changing only the live ICMP rate to 1 packet/second returned exactly 13
  passed and 1 failed; only `exact ICMP policer definition` failed. Its output
  was generic and exposed no learned target configuration. Restoring the rate
  returned the checker to 14 of 14.
- Shutting the r1 BGP peer deliberately forced a post-mutation `break.sh`
  validation failure. The injector exited nonzero with its generic abort
  message, restored exactly one first-position `INPUT` to `COPP` jump, and
  left the saved file SHA unchanged. After removing the shutdown and allowing
  routes to converge, the checker passed 14 of 14.
- Two subsequent break/check/solution cycles each produced exactly 13 passed
  and 1 failed while broken, with only `bounded local-versus-transit
  enforcement` failing, then returned to 14 of 14 after repair.

The final checker passed all 14 assertions. The same reviewer completed a
follow-up, confirmed all three original findings resolved, verified the
rollback-safe `break.sh` behavior, and reported no actionable findings.

## Limits

The lab validates a native Linux `iptables` INPUT policer with FRR routing. It
does not validate physical control-plane queues, ASIC forwarding, punt paths,
vendor default classes, IPv6, scale, long-duration rate behavior, or hardware
CoPP. The purpose-built Linux critical-role exception is intentional and
documented in `PROBE.md`.
