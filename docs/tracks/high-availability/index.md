# High Availability & Fast Convergence Track

Seven labs covering BFD, VRRP, anycast services, stateful firewall HA, Graceful Restart, and a capstone HA design combining multiple mechanisms.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [bfd-ospf](bfd-ospf.md) | Practice | cEOS | BFD with OSPF, sub-second link failure detection |
| [bfd-bgp](bfd-bgp.md) | Practice | cEOS | BFD with BGP, fast session teardown vs hold timer |
| [vrrp](vrrp.md) | Practice | cEOS | VRRP master/backup, virtual IP, priority, preemption |
| [anycast-dns](anycast-dns.md) | Practice | FRR | Anycast service VIP advertised from the servers (routing on the host), health-check route withdrawal, closest-instance + ~2 s failover |
| [service-ha](service-ha.md) | Practice | Linux | Active/backup stateful firewall pair: keepalived VIP + conntrackd state sync; a long-lived TCP flow dies on failover without sync, survives with it |
| [High-Availability Network Design](ha-network-design-ceos.md) | Capstone | cEOS | MLAG, VRRP tracking, OSPF+BFD+ECMP, dual-ISP BGP |
| [graceful-restart](graceful-restart.md) | Practice | cEOS | Graceful Restart for BGP on a route reflector, with service routes held stale during restart |

## Platform Notes

- **cEOS**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- **anycast-dns** (no cEOS needed): `docker build -t frr-lab:local images/frr/`, `docker build -t ops-lab:local images/ops-lab/`, and `docker build -t anycast-dns:local labs/anycast-dns/`
- **service-ha** (no cEOS needed): `docker build -t service-ha:local labs/service-ha/`
