# VyOS Platform Notes

Build the local VyOS image once:

```bash
docker build -t vyos:local -f Dockerfile.vyos .
```

**Architecture:** `vyos:local` inherits the architecture of the VyOS ISO/rootfs you build it
from, so build it from an ISO matching your host — amd64 on Intel/Linux, arm64 on Apple Silicon
(VyOS publishes arm64 rolling-release ISOs). The tag stays `vyos:local` either way, so the
topologies remain portable across both machines; `scripts/build-images.sh` deliberately skips
VyOS because it can't supply the ISO for you.

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

From config mode, prefix operational commands with `run`, for example:

```vyos
run show ip ospf neighbor
run show ip nhrp
```

## Current Image Quirk

The current local image can report an unhealthy container state because of a missing `/boot/grub/grub.cfg` inside the container filesystem. That does not prevent the DMVPN labs from booting or operating, but the health status is not yet clean.
