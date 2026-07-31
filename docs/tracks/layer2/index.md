# Layer 2 Track

Four labs covering VLAN/trunk fundamentals, edge hardening, Spanning Tree operations, and LACP EtherChannel on Arista cEOS.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [vlan-trunks-switchport-basics](vlan-trunks-switchport-basics.md) | Practice | VLAN creation, access ports, trunks, allowed VLANs, pruning symptoms |
| [campus-l2-hardening](campus-l2-hardening.md) | Practice | PortFast, BPDU Guard, Root Guard, storm control on a compact campus edge |
| [stp-operations](stp-operations.md) | Practice | Spanning Tree operations, port states, failure handling |
| [lacp-etherchannel](lacp-etherchannel.md) | Practice | 802.3ad LACP EtherChannel, Port-Channel, link aggregation |

## Platform

All labs use **Arista cEOS**:

```bash
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F
```
