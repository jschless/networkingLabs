# FRR Platform Notes

## Version

FRR 8.4 (`frrouting/frr:latest`). The enhanced `frr-lab:local` image adds `tcpdump` and `tshark` for packet capture.

```bash
docker build -t frr-lab:local images/frr/
```

## FRR 8.4 Syntax Changes

These differ from older documentation and Cisco-style commands:

| Feature | Correct FRR 8.4 Syntax | Old/Wrong |
|---------|------------------------|-----------|
| IS-IS on interface | `ip router isis CORE` | `isis enable CORE` |
| BGP VPNv4 AF | `address-family ipv4 vpn` | `address-family vpnv4` |
| eBGP policy | `no bgp ebgp-requires-policy` | (required in FRR 8.x) |
| MPLS on interface | `mpls enable` | — |

## Critical: `vtysh -b`

Always include `vtysh -b` in `exec:`:

```yaml
exec:
  - vtysh -b
```

FRR starts **before** ContainerLab creates veth pairs. Without `vtysh -b`, interface-level config (OSPF area assignments, `mpls enable`, IS-IS, etc.) is silently skipped for interfaces that didn't exist at FRR startup.

## Critical: MPLS sysctl

Set via `sysctls:`, not `exec:`:

```yaml
sysctls:
  net.mpls.platform_labels: "1048575"
```

`sysctls:` runs before the container process starts. If you use `exec: - sysctl -w net.mpls.platform_labels=1048575`, FRR has already started and MPLS routes fail to install.

## VRF Setup

For PE nodes that need Linux VRFs, use a bind-mounted `setup.sh` (called via `exec: - bash /setup.sh`) rather than inline exec commands. The script creates the VRF, enslaves interfaces, then runs `vtysh -b`:

```bash
#!/bin/bash
ip link add VRF-RED type vrf table 100
ip link set VRF-RED up
ip link set eth2 master VRF-RED
vtysh -b
```

## Daemons File

Every FRR node needs a `daemons` file. Always enable at minimum:

```
zebra=yes
staticd=yes
vtysh_enable=yes
```

Enable additional daemons as needed: `ospfd=yes`, `bgpd=yes`, `isisd=yes`, `eigrpd=yes`, etc.

## Packet Capture

The `frr-lab:local` image includes `tcpdump` and `tshark`:

```bash
./scripts/lab.sh capture <lab> <node> <iface> [filter]
./scripts/lab.sh pcap <lab> <node> <iface> [out.pcap]
```
