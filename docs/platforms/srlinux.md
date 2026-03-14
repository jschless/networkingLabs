# Nokia SR-Linux Platform Notes

## Pull Image

```bash
docker pull ghcr.io/nokia/srlinux:latest
```

Used by: `mpls-sr-srlinux`, `vxlan-evpn-srlinux`.

## ContainerLab Kind

Use `kind: srl`. Config is referenced via `startup-config:`:

```yaml
nodes:
  pe1:
    kind: srl
    image: ghcr.io/nokia/srlinux:latest
    startup-config: configs/pe1/config.cli
```

## Access

```bash
docker exec -it clab-<name>-<node> sr_cli
```

## Interface Naming

In topology links, use `e1-1`, `e1-2` etc. These map to SR-Linux `ethernet-1/1`, `ethernet-1/2`.

System/loopback: `system0` (subinterface 0).

## Config Format

SR-Linux config uses `enter candidate` / `commit now` blocks with absolute paths:

```
enter candidate

/interface ethernet-1/1 {
    admin-state enable
    subinterface 0 {
        ipv4 {
            address 10.0.12.1/30 { }
        }
    }
}

/network-instance default {
    interface ethernet-1/1.0 { }
    protocols {
        ospf {
            instance main {
                router-id 1.1.1.1
                area 0.0.0.0 {
                    interface ethernet-1/1.0 { }
                }
            }
        }
    }
}

commit now
```

## Key Differences from FRR/EOS

| Concept | SR-Linux |
|---------|----------|
| VPNv4 AF | `l3vpn-ipv4-unicast` |
| EVPN AF | `evpn` |
| L3VPN VRF | `network-instance` of `type ip-vrf` + `bgp-vpn` block |
| L2VPN (VXLAN/EVPN) | `network-instance` of `type mac-vrf` + `tunnel-interface` + `bgp-evpn` |
| Routing policy | Explicit `accept-all` policy required for BGP |

## No exec: Needed

SR-Linux loads `startup-config` automatically on boot. No `exec: vtysh -b` equivalent is needed.

## MPLS

SR-Linux handles MPLS natively in its dataplane. No `net.mpls.platform_labels` sysctl is required.
