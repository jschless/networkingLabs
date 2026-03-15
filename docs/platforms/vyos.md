# VyOS Platform Notes

Build the local VyOS image once:

```bash
docker build -t vyos:local -f Dockerfile.vyos .
```

This repository uses `vyos:local` for the DMVPN labs:

- `dmvpn-phase1`
- `dmvpn-phase2`
- `dmvpn-phase3`
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
