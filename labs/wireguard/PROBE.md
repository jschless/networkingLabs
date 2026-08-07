# Feature Probe Record — `wireguard`

## Scope and decision

- **Feature and learning objective:** Build and debug the native Linux kernel
  WireGuard reference model, including public-key identity, `AllowedIPs`
  cryptokey routing and inbound source authorization, current handshakes,
  transfer counters, and encrypted UDP/51820 evidence.
- **Decision:** Go with a documented critical-role platform exception. Keep
  `hub`, `gw-a`, and `gw-b` on purpose-built Linux because the kernel interface
  and `wg`/`wg-quick` operational model are the learned features. Use an
  incidental `ops-lab:local` container as an internal Layer 2 WAN instead of a
  host-root external bridge. No FRR is involved.
- **Reason and fidelity statement:** A generic router NOS would hide or replace
  the exact kernel, configuration, and peer-state surfaces the lab teaches.
  A bounded local image probe proved the load-bearing kernel interface. The
  legacy topology's host bridge dependency was independently shown invalid on
  this host.
- **Owner and date:** Codex implementation and main validation passes,
  2026-08-06. The completed target-topology evidence is in `VALIDATION.md`.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Ubuntu 22.04; Linux 5.15.0-181-generic x86_64 |
| ContainerLab version | 0.74.1, commit `1866b3a2b` |
| Docker version | Engine 29.5.3 |
| Legacy local lab image | `wireguard-lab:local`; ID `sha256:7ce2dc71eeb1e2a546e792578ed15984e613fbe68d9f507565d442ef5b41079f`; 94,265,868 bytes |
| Incidental WAN image | `ops-lab:local`; ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`; 68,762,000 bytes |
| Host memory/disk before implementation pass | 15,736 MiB RAM total; 1,901 MiB used; `/home` filesystem 289 GiB total, 137 GiB available |

## Smallest load-bearing test

The legacy topology was attempted first:

```text
./scripts/lab.sh deploy wireguard
```

It failed before creating containers because its external ContainerLab bridge
node required a host bridge named `br-wan`, which did not exist. The current
agent could not create that host-root bridge without host `NET_ADMIN`, so the
legacy topology was not a portable lab deployment.

The repository-owned lab image was then tested directly with only the bounded
container capabilities required by the feature:

```text
docker run --rm --cap-add NET_ADMIN --cap-add NET_RAW wireguard-lab:local \
  sh -c 'ip link add wgprobe type wireguard; ip address add 192.0.2.1/32 dev wgprobe; ip link set wgprobe up; wg show wgprobe; ip link delete wgprobe'

Result: exit 0. The kernel accepted creation, addressing, activation,
inspection, and deletion of a native WireGuard interface. The image reported
wireguard-tools v1.0.20210914.
```

Elapsed time and process peak RSS were not captured for the legacy observation;
they must not be inferred. The final four-container topology's available build
and point-memory evidence is recorded separately in `VALIDATION.md`.

## Cleanup and repeatability

- The bounded feature probe used `docker run --rm`; its container was removed
  automatically and the `wgprobe` interface was deleted inside its namespace.
- The legacy topology failed before container creation, so there was no legacy
  deployment to destroy.
- Two clean target-topology runs, including independent key generation,
  end-state checks, and clean destroys, are recorded in `VALIDATION.md`.

## Unsupported behavior and fallback

No router-NOS control plane is represented: that is an intentional scope
boundary, not a simulation. The internal WAN container provides only Ethernet
bridging. Clean deployment, learner configuration, checker, opaque fault,
repair, hub-transport capture, repeatability, point-resource, and cleanup
evidence are recorded in `VALIDATION.md`; that record also states the remaining
platform and coverage limits.
