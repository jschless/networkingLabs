# VyOS Platform Notes

## Building `vyos:local` (one time)

VyOS publishes no container image — you extract the root filesystem from a VyOS ISO,
then build. Two free ISO channels work (the ContainerLab `vyosnetworks_vyos` kind is
tested against **1.5 Q1 stream or newer**):

- **Stream** (snapshot of the upcoming LTS): <https://vyos.net/get/stream/>
- **Nightly rolling**: <https://vyos.net/get/nightly-builds/>

From the repo root:

```bash
# 1. Extraction tools (Debian/Ubuntu; on macOS: brew install squashfs libarchive)
sudo apt-get install -y squashfs-tools-ng libarchive-tools

# 2. Pull the rootfs out of the ISO you downloaded
bsdtar -xf vyos-1.5-stream-*-generic-amd64.iso live/filesystem.squashfs
sqfs2tar live/filesystem.squashfs > rootfs.tar

# 3. Build the image
docker build -t vyos:local -f Dockerfile.vyos .

# 4. Clean up the artifacts (they're gitignored anyway)
rm -rf live/ rootfs.tar
```

This mirrors the upstream
[ContainerLab VyOS kind instructions](https://containerlab.dev/manual/kinds/vyosnetworks_vyos/).

**Architecture:** `vyos:local` inherits the architecture of the VyOS ISO/rootfs you build it
from, so build it from an ISO matching your host — amd64 on Intel/Linux, arm64 on Apple Silicon.
Official VyOS nightlies are amd64-only; for arm64 use a community weekly autobuild
(e.g. [huihuimoe/vyos-arm64-build](https://github.com/huihuimoe/vyos-arm64-build)) or build your
own ISO. The tag stays `vyos:local` either way, so the topologies remain portable across both
machines; `scripts/build-images.sh` deliberately skips VyOS because it can't supply the ISO
for you.

**Deploying on macOS (Docker Desktop):** the `vyosnetworks_vyos` kind sets POSIX ACLs on the
node's lab directory, which macOS bind mounts (virtiofs) do not support — deploying a VyOS
topology straight from the repo fails every VyOS node with `pre-deploy: operation not
supported`. Work around it by copying the lab directory into a docker volume and pointing
containerlab at the volume's **VM-native** path (so the daemon-side bind mounts also resolve):

```bash
docker volume create clabwork
docker run --rm -v clabwork:/work -v "$PWD/labs/<lab>":/src alpine \
  sh -c 'rm -rf /work/<lab> && cp -r /src /work/<lab>'
docker run --rm --privileged --network host --pid host \
  -v /var/run/docker.sock:/var/run/docker.sock -v /run/netns:/run/netns \
  -v clabwork:/var/lib/docker/volumes/clabwork/_data \
  -w /var/lib/docker/volumes/clabwork/_data \
  ghcr.io/srl-labs/clab containerlab deploy \
  -t /var/lib/docker/volumes/clabwork/_data/<lab>/topology.clab.yml
```

Two more macOS notes: the Docker Desktop kernel has no `CONFIG_MACSEC`, so **macsec-basics
cannot run there at all**, and it ships no conntrack helper modules, so every VyOS commit
logs a harmless `system_conntrack` modprobe failure.

This repository uses `vyos:local` for:

- `ipsec-basics`
- `gre-ipsec`
- `macsec-basics`
- `black-core-routing`
- `dmvpn-phase1`
- `dmvpn-phase2`
- `dmvpn-phase3`
- `dmvpn-phase3-ipsec-capstone`
- `debug-dmvpn-phase1`
- `urpf-antispoofing`
- `mtu-pmtud-troubleshooting`
- `qos-enterprise`

## Access Model

VyOS labs use the `vyosnetworks_vyos` node kind and `config.boot` startup configs.

Open the CLI with:

```bash
./scripts/lab.sh cli dmvpn-phase1 hub
```

Typical workflow:

```vyos
configure
set ...
commit
save
```

`qos-enterprise` uses the current native `qos policy shaper` and
`qos interface ... egress` configuration model. VyOS renders its learned HTB,
DSCP classifiers, drop-tail, SFQ, and RED treatments through Linux `tc`; this
is real software scheduling, not Cisco MQC or hardware queue emulation.

## Current DMVPN Phase 2 compatibility boundary

The validated rolling image requires `/32` addresses on NHRP-used tunnel
interfaces. A shared tunnel `/24` is rejected, and broadcast OSPF over those
`/32` mGRE interfaces exchanges hellos but forms no adjacency because FRR
treats the links as unnumbered.

`dmvpn-phase2` is therefore a **Reference/Observation** compatibility study,
not a classic Phase 2 build. Its iBGP route reflector preserves remote-spoke
overlay next hops, but the initial FIB recursively forwards through the hub.
Direct peer forwarding appears only after hub `redirect` generates a Traffic
Indication and spoke `shortcut` resolves the peer. That is the optimization
mechanism associated with Phase 3; the lab labels it explicitly and does not
claim ordinary Phase 2 next-hop NHRP resolution. See the lab's `PROBE.md` for
the rejected live designs and its `VALIDATION.md` for the accepted environment.

From config mode, prefix operational commands with `run`, for example:

```vyos
run show ip ospf neighbor
run show ip nhrp
```

## Current Image Quirk

The current local image can report an unhealthy container state because of a missing `/boot/grub/grub.cfg` inside the container filesystem. That does not prevent the DMVPN labs from booting or operating, but the health status is not yet clean.

On the tested rolling image, the same failed system-option reset can make
`configure` print a warning that the boot configuration had an error. Confirm
the intended state with `show configuration commands` and operational `show`
or Linux `ip` commands; native commits and `save` still work in these labs.
Do not assume an identically worded warning is harmless on an untested image.
