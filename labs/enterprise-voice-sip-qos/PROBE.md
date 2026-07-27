# Feature Probe Record — `enterprise-voice-sip-qos`

## Scope and decision

- **Feature and learning objective:** Prove pinned Asterisk/SIPp registration,
  a deterministic call with at least 60 seconds of RTP, measurable sequence
  loss/jitter, a Linux `tc` priority bottleneck, and deterministic stateful
  one-way-media failure/repair.
- **Decision:** **Go with documented fallbacks.**
- **Reason and fidelity statement:** Asterisk/SIPp, RTP analysis, cEOS
  VLAN/SVI/DHCP relay, nftables NAT/conntrack, and Linux HTB classification are
  live. cEOSLab 4.35.2F accepted the ACL object but rejected SVI
  `ip access-group` attachment as unavailable on this hardware platform, so
  the authorized Linux nftables service guard is used. cEOS container
  interfaces do not provide a hardware egress scheduler, so the plan-authorized
  Linux `tc` bottleneck is used. LLDP-MED/PoE and vendor/PSTN integrations
  remain evidence-only.
- **Owner and date:** WP-09 / Codex, 2026-07-27.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux 5.15.0-181-generic x86_64 |
| ContainerLab version | 0.74.1, commit `1866b3a2b` |
| Docker version | 29.5.3 |
| NOS/service image and digest/tag | `ceos:4.35.2F` → `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`; `enterprise-voice-tools:1.0.0` → `sha256:869ba8e02ee9883907d4c249aaffd50e16f654df9b0faa922c7d37ae324dbf52`; base `ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90` |
| Voice software | Ubuntu Asterisk package `1:20.6.0~dfsg+~cs6.13.40431414-2build5`; SIPp 3.7.7 static binary, SHA-256 `8e8ecdbe923bf608c844038adfa35c8595400c4629d629f00d51539ac24cdfef` |
| Host memory/disk before probe | 15 GiB RAM, 10 GiB available; filesystem 289 GiB, 143 GiB available |

## Smallest load-bearing test

The disposable three-container probe is
`labs/enterprise-voice-sip-qos/probe/probe.sh`. It starts one PBX and two SIPp
endpoints on an isolated Docker network, authenticates both endpoints, places
one 65-second PCMU call, captures the PBX, runs the repository RTP analyzer,
prints memory, and removes every probe object through an EXIT trap.

```text
$ /usr/bin/time -f 'elapsed=%e max_rss_kib=%M' \
    docker build --no-cache -t enterprise-voice-tools:1.0.0 \
    labs/enterprise-voice-sip-qos/
elapsed=48.25 max_rss_kib=54476

$ labs/enterprise-voice-sip-qos/probe/probe.sh
Asterisk 20.6.0~dfsg+~cs6.13.40431414-2build5
Objects found: 2
call_elapsed=65.25
10.109.250.11:6000>10.109.250.10:<rtp> packets=3216 gaps=0 loss=0.0000% jitter=0.473ms
10.109.250.10:<rtp>>10.109.250.11:6000 packets=3216 gaps=0 loss=0.0000% jitter=0.508ms
10.109.250.12:6002>10.109.250.10:<rtp> packets=3216 gaps=0 loss=0.0000% jitter=0.492ms
10.109.250.10:<rtp>>10.109.250.12:6002 packets=3216 gaps=0 loss=0.0000% jitter=0.487ms
voice-probe-pbx 46.72MiB
voice-probe-phone-a 0.4MiB
voice-probe-phone-b 0.4MiB
```

The first registration attempt exposed identical SIP branch values in the two
generated scenarios. Prefixing the branch with the service/user identity made
each transaction unique; the corrected probe above passed.

The smallest independent scheduler probe also passed:

```text
$ /usr/bin/time -f 'elapsed=%e max_rss_kib=%M' docker run --rm \
    --cap-add NET_ADMIN enterprise-voice-tools:1.0.0 sh -c \
    'ip link add probe0 type dummy; ip link set probe0 up; ...; tc class show dev probe0'
class htb 1:10 parent 1:1 prio 0 rate 256Kbit ceil 1Mbit
class htb 1:1 root rate 1Mbit ceil 1Mbit
elapsed=0.44 max_rss_kib=30060
```

## Cleanup and repeatability

- **Destroy/cleanup command:** the probe EXIT trap runs
  `docker rm -f voice-probe-{pbx,phone-a,phone-b}` and
  `docker network rm enterprise-voice-feature-probe`, then removes its
  `mktemp` directory.
- **Orphan check:** `docker ps -a --filter name=voice-probe` and
  `docker network ls --filter name=enterprise-voice-feature-probe` returned no
  objects after the corrected run.
- **Result of a second run:** both authenticated registrations, a 65.21
  second call, four 3216-packet streams, zero gaps, 0.494–0.541 ms jitter, and
  cleanup repeated (`probe_total_elapsed=72.90`,
  `probe_runner_max_rss_kib=30288`).

## Unsupported behavior and fallback

The exact cEOSLab rejection was:

```text
interface Vlan10
 ip access-group DATA-BOUNDARY in
% Unavailable command (not supported on this hardware platform)
```

WP-09 explicitly authorizes Linux nftables when exact edge/NAT behavior is not
reliable and Linux `tc` when cEOS scheduling is unavailable. The lab therefore
states the syntax/platform boundary and tests the Linux fallback directly. It
does not rename vendor-neutral SIP/RTP behavior as a commercial call-manager
or SBC implementation, and it makes no live claim for LLDP-MED power policy,
PoE, PSTN/PRI/carrier operations, emergency calling, or vendor clustering.
