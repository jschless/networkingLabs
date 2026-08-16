# qos-enterprise validation record

## Final status

The main orchestrator built the endpoint image, deployed from a clean state,
walked the five-task learner flow, exercised atomic negatives and repeated
fault/recovery, recorded a final idle memory sample, and destroyed cleanly on
2026-08-07. A second clean focused deployment then validated every
reviewer-requested renderer assertion, revised checker count, and active-traffic
memory peak. The same reviewer approved the follow-up with no residual findings;
no validation or review items remain pending.

| Scope | Result |
|-------|--------|
| Native VyOS capability probe | Passed; see [PROBE.md](PROBE.md) |
| Endpoint image build and inventory | Passed |
| Clean deployment and preconfigured baseline | Passed |
| Hidden solution and end-state mechanisms | Passed |
| Pre-review healthy checker | Stable **24 passed, 0 failed** |
| Strengthened checker and focused negatives | Passed; stable **26/0** healthy |
| Pre-review repeated break/solution | Passed twice in each state |
| Packet, counter, shaping, and loss evidence | Passed |
| Final idle memory sample and clean destroy | Passed |
| Peak memory during active bounded traffic | Passed |
| `lab-tutor` student-flow validation | Unavailable globally; `labs/AUTHORING.md` was the fallback contract |
| Read-only reviewer | Same-reviewer follow-up approved; all six prior items resolved, no residual findings |

## Build and image evidence

| Item | Observed value |
|------|----------------|
| Build command | `docker build -t qos-lab:local labs/qos-enterprise/` |
| Build time | 9.33 seconds |
| Build runner maximum RSS | 53,516 KiB |
| Image ID | `sha256:c3299b2534a883d83c5da6d66245bdae09f3264ad9993759b6dc6c9d438e90f5` |
| Platform / size | linux/amd64 / 91,022,734 bytes |
| Installed packages | 110 |
| Sorted package/version inventory SHA-256 | `1e710f53a1a835982e17f928717a876e0fe57669a6cdcb7ac0307b9557a71015` |

A full Bookworm `debsecan` pass used the image's original
`/var/lib/dpkg/status` on 2026-08-07. It returned 111 package-CVE records,
52 unique CVEs, and 39 fixed-branch lines. These counts are a time-sensitive
scanner snapshot, not a zero-CVE claim or a statement that every record is
remotely exploitable in this lab.

The Dockerfile pins the external base and four direct package versions. Packages
resolved transitively by `apt` remain repository-time-dependent; the installed
inventory digest above documents the exact set resolved in this build. The
external base is
`debian@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818`
and directly pins four Bookworm packages. The Debian Security Tracker review
found:

| Package | Pinned Bookworm version | Tracker status reviewed |
|---------|-------------------------|-------------------------|
| `iproute2` | `6.1.0-3` | Tracker lists the version and no open issue |
| `iputils-ping` | `3:20221126-1+deb12u1` | CVE-2025-47268 remains open/unimportant for Bookworm |
| `iperf3` | `3.12-1+deb12u2` | CVE-2024-53580 is open/no-DSA; CVE-2024-26306 and CVE-2023-7250 are open/no-DSA/ignored |
| `tcpdump` | `4.99.3-1` | Open unimportant parser issues include CVE-2023-1801; the tracker also lists older unimportant parser issues |

Sources: Debian's tracker pages for
[iproute2](https://security-tracker.debian.org/tracker/source-package/iproute2),
[iputils](https://security-tracker.debian.org/tracker/source-package/iputils),
[iperf3](https://security-tracker.debian.org/tracker/source-package/iperf3), and
[tcpdump](https://security-tracker.debian.org/tracker/source-package/tcpdump).

The endpoints are isolated, short-lived lab containers; iperf3 listens only
inside the lab topology, and tcpdump parses bounded lab-generated traffic.
Those controls reduce exposure but do not fix the listed issues. Repeat the
advisory and full installed-package review by **2026-09-07**, or sooner if
Debian publishes an update.

## Clean deploy and baseline

The clean five-node deploy completed in 16.13 seconds with runner maximum RSS
41,904 KiB. Exact node/image inventory, all addresses and routes, and all three
iperf3 listeners passed.

The native startup configuration contained only `QOS-BASELINE` at 2 Mbit/s.
Kernel state was a 2 Mbit/s TBF with a 15 Kbyte burst and no HTB classes or
filters. Two bounded baseline runs produced aggregate receiver rates of
1,946,050 and 1,945,047 bit/s. Per-stream loss ordering changed between runs,
confirming that the classless baseline shapes the aggregate without providing
stable DSCP-aware treatment.

## Solved mechanism evidence

The README solution committed and saved the exact 15-line native `WAN-QOS`
configuration. The live checker and VyOS-native conversion of
`/config/config.boot` agreed on the exact healthy policy.

| Mechanism | Observed kernel state |
|-----------|-----------------------|
| Root | HTB `1:` at 2 Mbit/s, default `0x15` |
| Voice | `1:a`, 800 Kbit/s rate and effective 800 Kbit/s ceiling; PFIFO |
| Video | `1:14`, 600 Kbit/s rate and 2 Mbit/s ceiling; SFQ |
| Default/bulk | `1:15`, 600 Kbit/s rate and 2 Mbit/s ceiling; RED |
| EF classifier | Full-ToS `0xb8/0xff` match, 800 Kbit/s police, `action reclassify`, conforming traffic toward `1:a` |
| AF41 classifier | Full-ToS `0x88/0xff` match, 600 Kbit/s police, `action reclassify`, conforming traffic toward `1:14` |

The focused clean deployment completed in 16.08 seconds with runner maximum RSS
41,980 KiB. The exact three simultaneous, source- and ToS-specific one-packet
README captures using `ip[1] = 0xb8`, `ip[1] = 0x88`, and `ip[1] = 0x00` all
succeeded on WAN egress. The observed u32 mask was `00ff0000`, which matches the
complete ToS byte; ECN-marked variants were not validated and are not claimed
to enter the same explicit classes. A representative focused contention run
produced:

| Class | Receiver rate | Loss |
|-------|---------------|------|
| Voice / EF | 498,580 bit/s | 0% |
| Video / AF41 | 591,818 bit/s | 40.647% |
| Data / BE | 855,429 bit/s | 77.984% |
| Aggregate | 1,945,827 bit/s | — |

RED reported 2,623 early drops in that representative run. Final cumulative
state reported 5,237 RED early drops and 5,915 root drops. This proves RED was
active in the validated environment; the checker intentionally does not grade
an exact early-drop delta because short-run queue timing is not deterministic.

The current VyOS renderer placed an 800 Kbit/s admission policer on the EF rule
and a 600 Kbit/s admission policer on the AF41 rule, both with
`action reclassify`. Thus conforming AF41 traffic entered `1:14` while excess
continued toward default. During the 1 Mbit/s AF41 offer, class `1:14` showed
`borrowed 0` while default `1:15` borrowed. The configured 2 Mbit/s class-20
ceiling proves eligibility only; it does not prove that this matched flow
borrows. HTB priority matters only among traffic actually queued in eligible
classes and is not strict priority.

## Checker, negative, and recovery evidence

The original pre-review checker returned **24/0** twice before negative testing
and twice after recovery. That result remains historical evidence; the
strengthened 26-assertion checker supersedes it for acceptance.

- The original live-only and saved-only wrong-priority tests each returned
  **23/1** against the 24-assertion checker. The strengthened focused rerun
  supersedes those counts below.
- The first fault attempt encountered mounted helper mode `0700` after rollback
  was armed. The ERR path restored and verified the exact healthy live matcher
  and unchanged saved SHA. This was a forced post-arm transactional-recovery
  proof. The same-worker fix changed both host helpers to `0755`; the live bind
  reflected the fix without redeploy.
- In the first pass, `break.sh` then ran twice. The live CS6 matcher remained
  stable, output did not reveal the cause, and saved SHA
  `d70994100bc6a1e10bf391e6d8a756bb8d43f9a4e14a59be5669069bf189395e`
  stayed unchanged. The checker was stable at **19/5**, with only the live
  policy, classifier, all-class counter, EF envelope, and differentiated-loss
  assertions failing.
- In the first pass, `solution.sh` ran twice. Each run restored the exact live
  EF matcher, preserved the same saved SHA, and returned the checker to
  **24/0**.

The strengthened checker requires the DSCP match, flowid, police rate, and
`action reclassify` to coexist in the same leaf-filter record. It also proves
from fresh pre/post statistics that class-20 borrowing stays unchanged,
default borrowing increases, and RED total drops increase.

- Healthy state returned exactly **26/0** twice before focused negatives and
  returned to **26/0** after recovery, followed by a repeat healthy confirmation.
- A focused live-only wrong default priority returned exactly **25/1**; only
  the exact learned-policy assertion failed.
- A focused saved-only wrong default priority returned exactly **25/1**; only
  the exact saved-policy assertion failed.
- Repeated `break.sh` left the saved SHA
  `d70994100bc6a1e10bf391e6d8a756bb8d43f9a4e14a59be5669069bf189395e`
  unchanged and returned a stable **21/5**. The same five semantic assertions
  failed: live policy, classifier, all-class counters, EF envelope, and
  differentiated loss. The new borrowing and RED assertions remained healthy.
- `solution.sh` was invoked twice. It restored the exact EF matcher, preserved
  the same saved SHA, and the checker returned to **26/0**.

Failure messages remained generic throughout and did not print hidden expected
commands.

## Resources and cleanup

Repeated `docker stats --no-stream` samples during active checker contention
recorded these peaks:

| Node | Active-contention peak |
|------|------------------------|
| `client-voice` | 968 KiB |
| `client-video` | 956 KiB |
| `client-data` | 988 KiB |
| `server` | 4,920.32 KiB (~4.81 MiB) |
| `router` / VyOS | 259,788.8 KiB (~253.7 MiB) |

The original final idle sample remains useful as a separate baseline:

| Node | Final idle memory sample |
|------|---------------------|
| `client-voice` | 736 KiB |
| `client-video` | 744 KiB |
| `client-data` | 752 KiB |
| `server` | 2.715 MiB |
| `router` / VyOS | 258.7 MiB |

Clean destroy completed in 1.53 seconds with runner maximum RSS 40,752 KiB.
No lab containers, ContainerLab network, or generated lab directory remained.
The focused clean destroy completed in 1.57 seconds with runner maximum RSS
40,428 KiB and independently confirmed zero residual containers, networks, or
generated lab directory.
