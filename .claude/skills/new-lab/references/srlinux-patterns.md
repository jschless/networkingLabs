# SR-Linux Config Patterns (ghcr.io/nokia/srlinux:latest)

## When to Use SR-Linux

Use SR-Linux when the lab specifically targets Nokia SR-Linux features or when you want an alternative NOS perspective on the same protocol stack (e.g., MPLS SR, VXLAN/EVPN with SR-Linux native dataplane). cEOS is preferred for most labs.

## Topology

```yaml
name: <lab-name>

topology:
  nodes:
    r1:
      kind: srl
      image: ghcr.io/nokia/srlinux:latest
      startup-config: configs/r1/config.cli

  links:
    - endpoints: ["r1:e1-1", "r2:e1-1"]   # e1-N maps to ethernet-1/N in SR-Linux
```

- Kind: `srl`
- Config file: `config.cli` referenced via `startup-config:` key
- Interface naming in topology: `e1-1`, `e1-2` → maps to `ethernet-1/1`, `ethernet-1/2`
- System/loopback: `system0` (subinterface 0)
- Access: `docker exec -it clab-<name>-<node> sr_cli`
- No `exec:` needed — SR-Linux loads startup-config automatically
- No `sysctls:` needed for MPLS — SR-Linux handles it natively

## config.cli Format

```
enter candidate

/interface ethernet-1/1
  admin-state enable
  subinterface 0 {
    ipv4 {
      address 10.1.12.1/30 { }
    }
  }

/network-instance default
  interface ethernet-1/1.0 { }
  protocols {
    ospf {
      instance main {
        area 0.0.0.0 {
          interface ethernet-1/1.0 { }
        }
      }
    }
  }

commit now
```

## Key SR-Linux Patterns

### Routing Policy (required for BGP)

BGP requires explicit routing policy — always define accept-all:

```
/routing-policy
  policy accept-all {
    default-action {
      accept { }
    }
  }
```

### OSPF

```
/network-instance default/protocols/ospf/instance main/
  area 0.0.0.0 {
    interface ethernet-1/1.0 { }
    interface system0.0 {
      passive true
    }
  }
```

### IS-IS

```
/network-instance default/protocols/isis/instance main/
  net [ 49.0001.0000.0000.0001.00 ]
  level-capability L2
  interface ethernet-1/1.0 {
    circuit-type point-to-point
  }
  interface system0.0 {
    passive true
  }
```

### SR-MPLS (IS-IS)

```
/network-instance default/protocols/isis/instance main/
  segment-routing {
    mpls {
      dynamic-adjacency-sids {
        all-interfaces { }
      }
    }
  }
  interface system0.0 {
    ipv4-unicast {
      enable-bfd false
    }
    level 2 {
      metric 10
    }
    prefix-sids _idx 0 {
      ipv4-label-index 1
    }
  }
```

### BGP

```
/network-instance default/protocols/bgp
  autonomous-system 65001
  router-id 10.0.0.1
  neighbor 10.1.12.2 {
    peer-as 65002
    export-policy [ accept-all ]
    import-policy [ accept-all ]
    afi-safi ipv4-unicast { }
  }
```

### L3VPN (ip-vrf)

```
/network-instance CUST-A
  type ip-vrf
  interface ethernet-1/3.0 { }
  protocols {
    bgp-vpn {
      bgp-instance 1 {
        route-distinguisher { rd 65000:100 }
        route-target {
          export-rt target:65000:100
          import-rt target:65000:100
        }
      }
    }
  }
```

VPNv4 AF in SR-Linux: `l3vpn-ipv4-unicast` (NOT `ipv4-vpn` or `vpnv4`)

### VXLAN/EVPN (mac-vrf)

```
/tunnel-interface vxlan1
  vxlan-interface 100 {
    type bridged
    ingress {
      vni 100
    }
  }

/network-instance VLAN100
  type mac-vrf
  interface ethernet-1/2.0 { }
  vxlan-interface vxlan1.100 { }
  protocols {
    bgp-evpn {
      bgp-instance 1 {
        encapsulation-type vxlan
        vxlan-interface vxlan1.100
        evi 100
      }
    }
  }
```

EVPN AF in SR-Linux: `evpn`

## SR-Linux Labs in This Project

- `mpls-sr-srlinux`: IS-IS+SR-MPLS+BGP L3VPN reference lab (mirrors mpls-sr-isis-bgp)
- `vxlan-evpn-srlinux`: VXLAN+EVPN native reference lab (mirrors vxlan-evpn)
