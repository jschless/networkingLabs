# Feature Probe Record — `orchestrated-wan-overlay`

## Scope and decision

- **Feature and learning objective:** Prove a license-compatible controller/control-plane option, then prove PKI-capable tools and encrypted two-transport overlay support before teaching SD-WAN operations.
- **Decision:** documented fallback; rename required and completed as `orchestrated-wan-overlay`.
- **Reason and fidelity statement:** No locally runnable, license-compatible controller/edge candidate (vManage/vSmart/vEdge, Catalyst, OpenWISP, or flexiWAN) was present. The plan explicitly authorizes a provider-neutral controller API/state store, real PKI, BGP/route distribution *or* encrypted overlay, measured probes, and centralized policy. The host created a real WireGuard interface; local Python/OpenSSL/curl support a real mTLS PKI/controller implementation. This lab makes no SD-WAN product fidelity claim.
- **Owner and date:** WP-13 / 2026-07-23.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic` x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | `29.5.3` |
| Selected image | `orchestrated-wan-tools:1.0.0`, built from `debian:12.12-slim` |
| Host memory before probe | 15 GiB total, 11 GiB available |

## Smallest load-bearing test

```text
$ docker image ls --format '{{.Repository}}:{{.Tag}}' | rg -i 'vmanage|vsmart|vedge|catalyst|openwisp|flexiwan'
(no output)

$ docker run --rm --cap-add NET_ADMIN --cap-add NET_RAW wireguard-lab:local bash -ec \
  'wg --version; ip link add wgprobe type wireguard; ip -d link show wgprobe; ip link del wgprobe'
wireguard-tools v1.0.20210914 - https://git.zx2c4.com/wireguard-tools/
6: wgprobe: <POINTOPOINT,NOARP> ... wireguard ...

$ docker run --rm --entrypoint bash zt-access-tools:local -ec \
  'python3 --version; openssl version; curl --version | head -1'
Python 3.12.7
OpenSSL 3.3.7 7 Apr 2026
curl 8.14.1 ... OpenSSL/3.3.7 ...
```

The exact final image adds Debian `wireguard-tools`, Python 3.11, OpenSSL 3.0.20,
curl, nftables, `tc`, and capture tools. Its clean build took 11.15 seconds and
52,520 KB maximum builder RSS.

## Cleanup and repeatability

- **Destroy command:** `./scripts/lab.sh destroy orchestrated-wan-overlay`.
- **Checked:** `docker ps`, ContainerLab resources, the lab runtime directory, and `docker network ls` for `orchestrated-wan-overlay` names.
- **Result:** The disposable WireGuard device was deleted. Full clean-deploy/redeploy evidence is in `VALIDATION.md`.

## Unsupported behavior and fallback

Not proven or claimed: commercial controller licensing/bootstrap, OMP/TLOC/BFD protocol behavior, vendor GUI/API semantics, carrier MPLS, application DPI, or external SaaS availability. The fallback is exactly the acceptable outcome in [WP-13](../../plans/enterprise-expansion/13-sdwan-operations.md): controller/PKI distinct from edges, mTLS enrollment/revocation, two underlays, encrypted overlays, centralized desired/applied policy, measured path selection, and segment breakout.
