# gre-basics validation record

## Status

Main-orchestrator live validation passed the clean learner workflow, healthy
checker, focused and causal negatives, repeated deliberate fault/recovery,
active-load sampling, repository gates, two clean destroys, and read-only
review. The same reviewer completed follow-up and returned: `No actionable
findings remain`.

`lab-tutor` was unavailable. `labs/AUTHORING.md` was the authoring-contract
fallback; no tutor validation is claimed.

## Clean deployment and readiness

Two accepted clean deployments followed the final readiness fix:

| Run | Deploy time | Maximum command RSS | Readiness result |
|-----|-------------|---------------------|------------------|
| 1 | 81.72 seconds | 43,080 KiB | Both markers present and both target LAN DROP rules absent; rules remained absent after an additional 15 seconds |
| 2 | 81.17 seconds | 43,320 KiB | Both markers present and both target LAN DROP rules absent |

An earlier 10-second post-CLI stability design was rejected: `gw-b` wrote its
marker and then reinserted the `EOS_FORWARD` LAN ingress DROP. The accepted
helper requires 30 seconds of continuously stable absence after CLI readiness,
removing any matching rule that appears during the bounded watch.

## Learner workflow

| Task | Main-observed result |
|------|----------------------|
| 1 — baseline | Near and far WAN pings reported 0% loss; the private-LAN baseline reported 100% loss |
| 2 — native GRE | Exact native tunnel syntax was accepted, both `Tunnel0` interfaces were up, and reciprocal tunnel pings reported 0% loss |
| 3 — forwarding and capture | Host traffic passed in both directions; capture showed outer `203.0.113.1` ↔ `203.0.113.6` GREv0 and readable inner `192.168.1.10` ↔ `192.168.2.10` ICMP |
| 4 — broadcast comparison | After its Wait/DR election interval, the adjacency reached `FULL/DR` and `FULL/BDR` with the exact OSPF LAN routes |
| 4 — point-to-point | The transition briefly reconverged, then both ends returned to `FULL` and retained the exact OSPF LAN routes |

`solution.sh` was applied twice idempotently and emitted successful convergence
each time. The checker run after each application returned **49/0**. The
healthy checker also repeatedly returned **49/0** during active load, after
active load, and on the second clean deployment.

## Focused and causal negatives

The focused atomic results were:

| Negative | Checker | Isolation result |
|----------|---------|------------------|
| Wrong readiness marker | **48/1** | Only the intended marker assertion failed |
| Removed passive interface | **48/1** | Only the intended passive-LAN assertion failed |
| Stable tunnel TTL 254 | **48/1** | Only the intended exact-TTL assertion failed after a 15-second stabilization wait |

The first immediate TTL-254 read observed the expected adjacency bounce and
was not used as the atomic result. PMTUD was **not** tested as a focused atomic
negative and is not claimed.

Two causal negatives proved behavior beyond configuration presence:

- Removing `tunnel routes` on `gw-a` preserved its Full neighbor, removed the
  remote OSPF LAN route, and produced **45/4**.
- Removing the outer-TTL override on both ends captured outer GRE TTL 1 and
  inner OSPF TTL 1. Adjacency, routes, and host traffic failed, producing
  **41/8**. `solution.sh` restored **49/0**.

## Deliberate fault and recovery

The recursive endpoint-resolution scenario was exercised twice.

| Run | Break convergence | Fault checker | Repair convergence | Recovered checker |
|-----|-------------------|---------------|--------------------|-------------------|
| 1 | 47.55 seconds | **42/7** | 8.17 seconds | **49/0** |
| 2 | 49.18 seconds | **42/7** | 17.33 seconds | **49/0** |

Both fault runs reported a recursive route loop/resolution over another tunnel
in interface detail while the near underlay next-hop ping retained 0% loss.
The identical seven-failure result was stable across both runs.

### Reviewer-fix validation

The reviewer-requested transactional fault fix was retested from a fresh
deployment. A file replacement had briefly reset `break.sh` to mode `0600`, so
direct execution failed with permission denied; the mode was restored and all
source shell scripts were verified as `0755` before the live retest.

After the healthy solution converged and the checker returned **49/0**, forced
`TERM` was sent on attempt 2 after the exact injected route was observed.
`break.sh` exited 143, and its trap reported that it removed the injected route
and restored full service. The exact route was absent and the checker returned
**49/0**. A subsequent normal `break.sh` run deliberately retained the fault
and reproduced the identical **42/7** result; `repair.sh` restored **49/0**.
Clean destroy removed the target lab.

All original reviewer findings were addressed. The same read-only reviewer
completed follow-up and returned: `No actionable findings remain`.

## Active resources and cleanup

Five active-flood samples produced these observed peaks:

| Node | Peak memory |
|------|-------------|
| `gw-a` | 1.13 GiB |
| `gw-b` | 1.13 GiB |
| `host-a` | 664 KiB |
| `host-b` | 644 KiB |
| `internet` | 1.949 MiB |

Approximate total observed memory was 2.263 GiB; maximum observed CPU was about
9.90%. Every node reported `OOMKilled=false`. The checker remained **49/0**
during and after active traffic. These are point-in-time, short active samples,
not capacity guarantees.

Two final clean destroys completed as follows:

| Run | Destroy time | Maximum command RSS | Residual check |
|-----|--------------|---------------------|----------------|
| 1 | 1.75 seconds | 41,052 KiB | No target containers or generated lab directory |
| 2 | 1.84 seconds | 40,916 KiB | No target containers or generated lab directory |

## Repository gates and limits

- Target `bash -n` passed. ShellCheck at warning severity passed with no
  warning-level findings; a separate default-severity invocation reported only
  informational SC1091 for not following the sourced shared check library.
- YAML parsing, markdown spacing, docs admonitions, `git diff --check`, and
  strict MkDocs passed.
- `lint-labs` passed with 143 labs checked and 53 distinct images; quiz
  validation passed for 44 quizzes.

The licensed `ceos:4.35.2F` image is required. Arm64 was not live-tested.
Results apply to software cEOS; physical hardware and ASIC forwarding were not
tested. GRE visibility proves encapsulation without encryption; this lab makes
no encryption claim. Read-only review and same-reviewer follow-up are complete.
