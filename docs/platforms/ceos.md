# Arista cEOS Platform Notes

## Import

Download `cEOS-lab-4.35.2F.tar` from [arista.com](https://www.arista.com/en/support/software-download) (free account required), then import once:

```bash
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F
```

## ContainerLab Kind

Use `kind: ceos`. ContainerLab handles env vars and management interface automatically.

Config is referenced via `startup-config:` (not `binds:`):

```yaml
nodes:
  leaf1:
    kind: ceos
    image: ceos:4.35.2F
    startup-config: configs/leaf1/startup-config
```

## Access

```bash
docker exec -it clab-<name>-<node> Cli
# or using the helper:
./scripts/lab.sh Cli <name> <node>
```

## Interface Naming

In topology links, use `eth1`, `eth2`. These map to EOS `Ethernet1`, `Ethernet2`. Management is `Management0` in the `management` VRF.

## Critical: No switchport on Routed Interfaces

cEOS Ethernet interfaces default to L2 switchport mode. **Always** add `no switchport` before assigning an IP address:

```eos
interface Ethernet1
   no switchport
   ip address 10.0.0.1/30
```

Without `no switchport`, the IP address is silently rejected and the interface won't appear in `show ip interface brief`.

## Critical: `send-community extended` for eBGP EVPN

In EOS, `send-community extended` is **not** automatic for eBGP neighbors. Without it, route-targets are stripped and EVPN doesn't work despite BGP sessions being up.

```eos
router bgp 65001
   neighbor 10.0.0.2 send-community extended
```

Add this on **every** node participating in eBGP EVPN (both directions).

Symptom: `show vxlan vtep` shows 0 remote VTEPs even though IMET routes appear in `show bgp evpn`.

## Key EOS Syntax

```eos
! Enable IPv4 routing (required — EOS defaults to L2 switching)
ip routing

! VRF
vrf instance VRF-RED
ip routing vrf VRF-RED

interface Ethernet1
   vrf VRF-RED
   ip address 10.0.0.1/30

! Anycast gateway for EVPN IRB
ip virtual-router mac-address 00:1c:73:aa:aa:aa
interface Vlan10
   ip address virtual 10.10.10.1/24

! GRE tunnel (requires tunnel path-mtu-discovery + ttl 255 for OSPF)
interface Tunnel0
   tunnel source Ethernet1
   tunnel destination 203.0.113.2
   tunnel path-mtu-discovery
   tunnel ttl 255

! BGP ECMP
router bgp 65001
   maximum-paths 4 ecmp 4
   bgp bestpath as-path multipath-relax
```

## GRE/OSPF Gotchas on cEOS 4.35.2F

1. **OSPF TTL=1 over GRE**: EOS copies inner IP TTL to the GRE outer header. OSPF hellos have TTL=1 and are dropped in transit. Fix: `tunnel path-mtu-discovery` + `tunnel ttl 255` on the tunnel interface.

2. **OSPF routes not installed over tunnel**: EOS default is `no tunnel routes`. The adjacency forms but routes aren't installed. Fix: add `tunnel routes` under `router ospf 1`.

3. **Transit forwarding blocked by iptables**: cEOS installs DROP rules in `EOS_FORWARD` for data-plane interfaces. Fix via topology exec:
   ```yaml
   exec:
     - bash -c "iptables -D EOS_FORWARD -i eth1 -j DROP 2>/dev/null || true"
   ```
