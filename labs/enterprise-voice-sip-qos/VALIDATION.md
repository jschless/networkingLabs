# Validation Record — `enterprise-voice-sip-qos`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-27, WP-09 / Codex |
| Host OS/kernel | Linux 5.15.0-181-generic x86_64 |
| ContainerLab/Docker versions | ContainerLab 0.74.1 (`1866b3a2b`); Docker 29.5.3 |
| Image tags/digests | `ceos:4.35.2F` → `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`; `enterprise-voice-tools:1.0.0` → `sha256:869ba8e02ee9883907d4c249aaffd50e16f654df9b0faa922c7d37ae324dbf52` |
| Repository commit | Validation began from `origin/main` at `48f838a303dd168979ff5a37c55b0cf4049caa45`; final implementation commit recorded below after commit |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Image build | `/usr/bin/time docker build --no-cache -t enterprise-voice-tools:1.0.0 labs/enterprise-voice-sip-qos/`; passed | 48.25 s | runner max RSS 54,476 KiB |
| Deploy | `/usr/bin/time sudo containerlab deploy -t labs/enterprise-voice-sip-qos/topology.clab.yml`; 10 nodes healthy | 46.77 s | runner max RSS 43,316 KiB |
| Healthy/check | `./labs/enterprise-voice-sip-qos/check.sh`; 20 passed, 0 failed | not separately timed | steady container total approximately 2.62 GiB |
| Break-It failure | `break-it.sh && check.sh`; signaling/contacts passed, public-media and four-stream assertions failed, exit 1 | not separately timed | within steady target |
| Minimal repair/check | `repair-break-it.sh && check.sh`; 20 passed, 0 failed | not separately timed | within steady target |
| Destroy/cleanup | `containerlab destroy -t labs/enterprise-voice-sip-qos/topology.clab.yml --cleanup`; scoped topology removed | 2.26 s | runner max RSS 42,684 KiB; no lab runtime |
| Redeploy/recheck/destroy | deploy 35.58 s; blank-state proof; `solution.sh` 9.20 s; 20 passed, 0 failed; final destroy 2.38 s | 47.16 s excluding check | runner max RSS 43,896/30,104/41,640 KiB; observed steady 2.35 GiB |

## Positive and negative evidence

- Blank state had no phone/data DHCP addresses, a `WITHHELD` service marker,
  no edge nft/`tc` policy, and zero SIP contacts.
- The completed path proved separate VLAN 10/20 leases, PBX A and SIP SRV
  answers, a successful live NTP query, two authenticated contacts, SIP
  setup/teardown, four PBX RTP streams, and two remote RTP streams.
- Five or more deterministic calls were run across probe, baseline,
  contention, failure, repair, and repeatability walks. Healthy eight-second
  calls produced approximately 396–400 packets per stream (about 50 pps),
  zero sequence gaps, and sub-2 ms jitter.
- The 8 Mb/s, 1200-byte UDP best-effort offer was constrained by the 1 Mb/s
  bottleneck and lost more than 20%, while both RTP directions remained below
  1% loss and 10 ms jitter. The untrusted EF named counter and both HTB class
  counters increased.
- A data-port client with `10.109.20.250/24` could not reach the voice SVI.
  The PBX nftables guard denied data-subnet SIP and management ports.
- Stateful NAT exposed only UDP/5060 and UDP/10000-10099 and conntrack showed
  the remote media flow; no unrestricted UDP forward rule was used.
- In Break-It, both contacts and SIPp call completion remained green, but the
  remote endpoint targeted private `10.109.30.10`, the edge dropped that
  direction, the PBX saw two rather than four RTP streams, and `check.sh`
  exited 1. Repair restored public `192.0.2.110` media and removed only the
  tagged fault rule.

## Repository gates

Final exact results:

```text
python3 scripts/lint-labs.py
OK — 137 labs checked, 47 distinct images, all consistent

./scripts/check-docs-admonitions.sh
OK: no malformed admonitions in docs/

mkdocs build --strict
exit 0; documentation built in 18.14 seconds

shellcheck -S warning scripts/*.sh labs/*/check.sh
exit 0; no findings
```

Additional checks passed: Bash syntax for every lab script, ShellCheck for all
lab helper/init scripts, XML parsing for all SIPp scenarios, Python compilation
for `rtp_analyze.py`, and `git diff --check`. The enterprise coverage validator
was also run; it reported the pre-existing unrelated missing path
`labs/fixtures/wireless-core-operations` at topic 14. This package's new voice
topic registration itself produced no finding.

## Limitations, refresh, and cleanup

- **Unsupported or evidence-only behavior:** cEOSLab SVI ACL attachment and
  hardware scheduling are unavailable; the live, documented Linux
  nftables/`tc` fallbacks are tested. LLDP-MED/PoE, PSTN/PRI/carrier ordering,
  emergency calling, vendor clustering, commercial B2BUA behavior, handset
  DSP/MOS, and physical queue hardware remain evidence-only/product-only.
- **Image vulnerability-refresh review/result:** Ubuntu base is immutable by
  digest and all installed packages/SIPp are version-pinned. This is a lab
  dependency record, not a security certification. Review monthly and triage
  actionable critical/high advisories per `docs/image-policy.md`; next review
  due 2026-08-27.
- **Residual runtime artifacts checked and cleanup result:** final scoped
  destroy reported 2.38 seconds. Counts were zero for
  `clab-enterprise-voice-sip-qos-*` containers/networks and all
  `voice-probe-*` containers/networks; the generated
  `clab-enterprise-voice-sip-qos/` directory was absent. No pcap, lease,
  namespace, or runtime state is versioned.
- **Follow-ups not represented as complete:** PBX HA, commercial SBC
  clustering, TLS/SRTP, LLDP-MED/PoE, PSTN/emergency calling, and concurrent
  hardware-phone capacity validation.
