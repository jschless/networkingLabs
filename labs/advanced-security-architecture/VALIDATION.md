# Validation Record — `advanced-security-architecture`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-28, Codex |
| Host OS/kernel | Ubuntu Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab/Docker versions | ContainerLab `0.74.1` (`1866b3a2b`); Docker Client/Server `29.5.3`; overlay2; cgroup v2 |
| Image tags/digests | `advanced-security-tools:1.0.0` ID `e5e1f8273c85...`, built from Debian digest `d5d3f9c23164...`; `advanced-security-fw:1.0.0` ID `9e6d5bf29751...`, built from Suricata digest `f8e7d04babea...` |
| Repository base | `91a9f9e1485ffe9ff4487cc5308549ae1b9e0c0d` (`origin/main`) |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Build | `docker build -t advanced-security-tools:1.0.0 ...`; `docker build -f Dockerfile.fw -t advanced-security-fw:1.0.0 ...` | cached/final builds completed | image sizes 255,329,864 and 503,654,613 bytes |
| Deploy | `/usr/bin/time -v ./scripts/lab.sh deploy advanced-security-architecture`; 12 containers and 11 links | 4.92 s | runner max RSS 41.4 MiB |
| Starting-state gate | no `asa` nft table, no Suricata process, WAF `modsecurity off`, partner policy absent, DNS/proxy ports absent; nginx/rsyslog and both access VRFs ready | observed, no fixed sleep | lightweight baseline |
| Documented student path | entered the collapsed task commands in order without reading a solution config file | about 3 s after readiness | services ready through observed logs/listeners |
| Healthy/check | `./check.sh` | 28.944 s | 288.07 MiB steady total; 380.55 MiB sampled peak total |
| Break-It failure | `./break-it.sh`; normal public HTTP 200, partner direct origin HTTP 200; `./check.sh` | expected nonzero | 54 pass, exactly 1 fail: partner origin-bypass assertion |
| Diagnosis | direct event `asa-break-diagnosis`; broad rule handle 32 reached 15 packets/1,114 bytes; central evidence contained origin 200 and no PEP/WAF event | immediate | no resource change |
| Minimal repair/check | `./repair-break-it.sh` deleted only handle 32; `./check.sh` | 28.87 s | 55/55 pass |
| Destroy/cleanup | `/usr/bin/time -v ./scripts/lab.sh destroy advanced-security-architecture` | 2.79 s | runner max RSS 40.8 MiB |
| Redeploy/recheck/destroy | clean deploy; blank-state gate; documented task commands; sampled-memory `./check.sh`; destroy and zero-resource audit | 4.92 s deploy, 28.944 s check, 2.79 s destroy | 288.07 MiB steady, 380.55 MiB peak |

The sampled peak sums every topology container’s cgroup
`memory.current` at 100 ms intervals during the full check. The host kernel does
not expose `memory.peak`; the sampling method and value are therefore stated
explicitly. Both steady and peak are far below the 9/11 GiB package targets and
leave well over 3 GiB host headroom.

## Positive and negative evidence

The final check passed 55 assertions:

- three live VRFs (`USER`, `SERVER`, `MGMT`), stateful return ordering, exact
  DNAT, source NAT, public WAF publication, intentional hairpin, and direct
  internal application flow;
- independent internet-to-origin, partner-to-origin, and internet-to-private-WAF
  denials;
- partner signed-assertion permit for one resource and PEP denial for the
  internal resource;
- admin and dedicated break-glass management permits plus user management
  denial;
- controlled DNS positive/negative answers, public-resolver bypass denial,
  approved proxy egress, proxy destination denial, and direct-web denial;
- Suricata alert-only and scoped drop evidence, normal-path preservation,
  deterministic ModSecurity 403/audit, live excess-rate drop counter, and
  conntrack translation evidence;
- wrong-token RTBH denial, allowlisted install, selected-prefix outage,
  unaffected sibling service, timed recovery, and install/clear logs;
- shared event IDs across WAF, origin, PEP permit/deny and policy-probe denial,
  plus DNS source/query and proxy source/destination evidence.

The topology is intentionally IPv4-only and makes no untested IPv6-enforcement
claim. Safe test paths and markers are repository-owned and contain no
exploitation guidance.

## Break-It evidence

```text
normal-public=200
partner-direct-origin=200
check-exit=1
FAIL partner cannot bypass PEP/WAF to protected origin — expected HTTP 000, got 200
Results: 54 passed, 1 failed

BREAKIT broad partner origin bypass # handle 32
counter packets 15 bytes 1114

central event=asa-break-diagnosis:
protected-app ... action=http status=200 path=/partner-app source=10.114.40.10
# no PEP or WAF record for that event

Removed only the shadowing rule (handle 32).
Results: 55 passed, 0 failed
```

## Repository gates

```text
python3 scripts/lint-labs.py
OK — 140 labs checked, 51 distinct images, all consistent

python3 scripts/validate-enterprise-coverage.py
OK — 29 enterprise coverage topic(s) validated

./scripts/check-docs-admonitions.sh
OK: no malformed admonitions in docs/

mkdocs build --strict
INFO - Documentation built in 20.10 seconds
# only the repository's two existing unnavved troubleshooting-page notices

shellcheck -S warning scripts/*.sh labs/*/check.sh
exit 0
```

Targeted ShellCheck also covered this lab’s lifecycle/evidence/setup scripts and
the changed `scripts/build-images.sh`.

## Limitations, refresh, review, and cleanup

- **Unsupported/evidence-only:** no OPNsense/FortiOS appliance automation or
  HA; no vendor application database, production threat feed, TLS interception,
  malware sandbox, CASB/DLP, or cloud SSE. Squid destination policy is not
  called application identification. See `EVIDENCE-MAPPING.md`.
- **Identity scope:** the resource PEP validates a pre-issued signed lab
  assertion and one resource policy. Keycloak/device-certificate administration
  remains in the prerequisite zero-trust lab.
- **IPv6:** the topology is IPv4-only; dual-stack policy is covered separately
  and is not represented here.
- **Image refresh:** bases are digest-pinned and key service packages are exact
  versions. No local vulnerability scanner was installed, so this record does
  not claim a clean CVE scan. Maintainers must perform the monthly/advisory
  review required by `docs/image-policy.md`; next review is due 2026-08-28.
- **Security-claim review:** the author completed a claim/fidelity audit. The
  plan-required independent second reviewer remains to sign off in the PR; no
  false independent-review claim is made.
- **Final cleanup:** `containers=0 network=0 links=0 qemu=0 lab_dir=absent`.
  All policy, tokens, logs, queues, and service state were container-local. No
  QEMU VM, tap, overlay disk, host namespace, or runtime secret directory was
  created.
- **Follow-up not represented as complete:** independent security-claim review
  only. All implementation and live gates are complete.
