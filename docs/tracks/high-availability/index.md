# High Availability & Fast Convergence Track

Five labs covering BFD, VRRP, Graceful Restart, and a capstone HA design combining multiple mechanisms.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [bfd-ospf](bfd-ospf.md) | Practice | FRR | BFD with OSPF, sub-second link failure detection |
| [bfd-bgp](bfd-bgp.md) | Practice | FRR | BFD with BGP, fast session teardown vs hold timer |
| [vrrp](vrrp.md) | Practice | FRR | VRRP master/backup, virtual IP, priority, preemption |
| [ha-network-design-ceos](ha-network-design-ceos.md) | Practice | cEOS | MLAG, VRRP tracking, OSPF+BFD+ECMP, dual-ISP BGP |
| [graceful-restart](graceful-restart.md) | Practice | FRR | Graceful Restart for BGP/OSPF, stale route forwarding |

## Platform Notes

- **FRR labs**: `docker build -t frr-lab:local images/frr/`
- **cEOS**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
