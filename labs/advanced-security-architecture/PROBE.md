# Feature Probe Record — `advanced-security-architecture`

## Scope and decision

- **Feature and learning objective:** choose a reproducible firewall/WAF/IPS
  platform and prove state/NAT tooling, inline safe alert/drop behavior, and a
  deterministic benign WAF action before building the capstone.
- **Decision:** documented fallback.
- **Reason and fidelity statement:** the plan-authorized Linux fallback is
  used: nftables 1.0.9 + Suricata 7.0.10 on the gateway, and nginx 1.22.1 +
  ModSecurity 3.0.9/OWASP CRS 3.3.4 on the WAF. These are live mechanisms, not
  an OPNsense/FortiOS UI, vendor application database, production feed, or
  commercial NGFW claim.
- **Owner and date:** Codex, 2026-07-28.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Ubuntu Linux, `5.15.0-181-generic`, x86_64 |
| ContainerLab version | `0.74.1` (commit `1866b3a2b`) |
| Docker version | Client/Server `29.5.3` |
| Host memory/disk before probe | 15 GiB RAM, about 13 GiB available; 140 GiB free on `/` |
| Appliance candidates | local OPNsense qcow2 (2.2 GiB disk, 3 GiB virtual); imported `vr-fortios:7.4.11-nobootstrap` image ID `9d5a60027fd5...` |
| Tools base | `debian@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c` |
| Firewall/IPS base | `jasonish/suricata@sha256:f8e7d04babeaab8bfac7e327b09e8f7471f144b0b205bfc503f7dd3130a6d2e7` |
| Built probe images | `advanced-security-tools:1.0.0` ID `e5e1f8273c85...` (255,329,864 bytes); `advanced-security-fw:1.0.0` ID `9e6d5bf29751...` (503,654,613 bytes) |

Exact service packages in the tools image:

```text
dnsmasq=2.90-4~deb12u2
libmodsecurity3=3.0.9-1+deb12u2
modsecurity-crs=3.3.4-1+deb12u3
nftables=1.0.6-2+deb12u2
nginx=1.22.1-9+deb12u9
rsyslog=8.2302.0-1+deb12u1
squid=5.7-2+deb12u6
```

The firewall image reports Suricata 7.0.10, nftables 1.0.9,
rsyslog 8.2510.0, and conntrack-tools 1.4.7.

## Appliance platform gate

The tracked OPNsense lab was inspected without modification. Its shared runtime
requires a locally prepared disk plus root-created taps:

```text
$ labs/opnsense-ngfw-basics/start-opnsense.sh
Run with sudo: QEMU needs tap interfaces and KVM access.
$ echo $?
1
```

`sudo -n true` also returned `sudo: a password is required`. The disk exists,
but the assigned unattended lifecycle cannot run or validate its version,
API/CLI configuration, IDS/IPS, logs, and overlay teardown. The imported
FortiOS image has no repository-owned activation/license workflow. Using it
would not be a reproducible, license-compatible result. Per WP-14, the next and
only honest fallback is Linux nftables + Suricata + proxy/WAF components.

## Smallest load-bearing test

Two disposable containers on one Docker bridge were sufficient. The firewall
container held nftables input/output queue rules and Suricata queue 0; the
service container held a loopback origin and nginx/ModSecurity. Both directions
of TCP/8080 entered NFQUEUE so flow-aware HTTP inspection had complete state.

Command shape:

```text
docker network create asa-probe-net
docker run -d --privileged --name asa-fw-probe \
  --network asa-probe-net advanced-security-fw:1.0.0 sleep infinity
docker run -d --name asa-waf-probe \
  --network asa-probe-net advanced-security-tools:1.0.0 sleep infinity

suricata -q 0 -S /tmp/suricata/test.rules -l /tmp/suricata -D
nft add rule inet probe output ... tcp dport 8080 queue num 0
nft add rule inet probe input  ... tcp sport 8080 queue num 0
curl http://SERVICE:8080/{,ids-alert,ids-block}
curl 'http://SERVICE:8080/?probe=LAB-WAF-SAFE-TEST'
```

Relevant output after 6.522 seconds:

```text
normal=200 ids_alert=404 ips_block=000 waf_safe=403
This is Suricata version 7.0.10 RELEASE
nftables v1.0.9 (Old Doc Yak #3)
[1:1140001:1] LAB safe IDS alert
[Drop] [1:1140002:1] LAB safe IPS block
ModSecurity: Access denied with code 403 ... [id "1141001"]
asa-fw-probe 72.39MiB
asa-waf-probe 13.7MiB
```

The alert URI reached the simple origin and returned its expected 404 while
still alerting. The block URI timed out at HTTP code 000 and logged `[Drop]`.
Normal traffic stayed 200. The literal benign marker returned 403 and named
rule 1141001. This proves the load-bearing queue and WAF actions; the complete
lab separately proves routed forwarding, state, NAT, VRFs, proxy/DNS, identity
resource policy, logging, rate limiting, and RTBH.

## Cleanup and repeatability

- **Destroy/cleanup command:** `docker rm -f asa-fw-probe asa-waf-probe`;
  `docker network rm asa-probe-net`, protected by an exit trap.
- **Orphans checked:** matching `docker ps -a` and `docker network ls` rows were
  both zero after the final run.
- **Second run:** the corrected two-direction NFQUEUE probe repeated the alert,
  drop, normal 200, WAF 403, and clean removal. The complete topology then
  deployed twice from container-local blank policy.

## Unsupported behavior and fallback limits

No OPNsense/FortiOS GUI/API, HA pair, vendor URL/application control, licensed
feed, cloud sandbox, TLS interception, CASB/DLP, or SSE PoP was proven. Port,
path, and destination rules are named exactly that. The lab uses one gateway;
HA is not planned. Product-only capabilities remain mapped as evidence/design
review in `EVIDENCE-MAPPING.md`.
