# MPLS / BGP / IS-IS / SR Lab — Verification

## Deploy / Destroy

```bash
# From the lab directory:
sudo containerlab deploy --topo topology.clab.yml --reconfigure
sudo containerlab destroy --topo topology.clab.yml --cleanup
```

## Attach to a node

```bash
sudo docker exec -it clab-mpls-sr-isis-bgp-pe1 vtysh
```

---

## IS-IS Verification

```
# Adjacencies (expect level-2 neighbours on all transit interfaces)
show isis neighbor

# IS-IS database (all routers should appear)
show isis database

# SR-MPLS prefix SIDs (each loopback should have an index)
show isis segment-routing node

# Computed IS-IS routes
show isis route
```

---

## MPLS / SR Forwarding

```
# FIB with MPLS labels  (run on p1 or p2)
show mpls table

# SR label bindings
show isis segment-routing prefix-sids

# Verify MPLS is enabled on transit interfaces
show interface eth1
#   → look for "mpls enabled"
```

---

## BGP Verification

```
# On rr1 – check RR clients are up
show bgp summary

# VPNv4 table on rr1 (should see routes from both PEs)
show bgp vpnv4 all

# On pe1 – iBGP to rr1
show bgp summary

# VPNv4 table on pe1
show bgp vpnv4 unicast all

# VRF routing table on pe1
show bgp vrf CUST-A ipv4 unicast

# Kernel VRF table
show ip route vrf CUST-A
```

---

## End-to-End Connectivity

```bash
# Ping from ce1 loopback to ce2 loopback
sudo docker exec clab-mpls-sr-isis-bgp-ce1 \
  ping -I 10.100.1.1 10.100.2.1 -c 5

# Traceroute to see MPLS hops (labels won't show in traceroute
# inside containers, but path should traverse pe1→p1→p2→pe2)
sudo docker exec clab-mpls-sr-isis-bgp-ce1 \
  traceroute -s 10.100.1.1 10.100.2.1
```

---

## IP Addressing Reference

| Node | Loopback      | SID label |
|------|---------------|-----------|
| rr1  | 10.0.0.1/32  | 16001     |
| pe1  | 10.0.0.2/32  | 16002     |
| pe2  | 10.0.0.3/32  | 16003     |
| p1   | 10.0.0.4/32  | 16004     |
| p2   | 10.0.0.5/32  | 16005     |
| ce1  | 10.100.1.1/32 | —        |
| ce2  | 10.100.2.1/32 | —        |

| Link           | Subnet         |
|----------------|----------------|
| ce1 ↔ pe1     | 192.168.10.0/30 |
| pe1 ↔ p1      | 10.1.0.0/30    |
| p1  ↔ rr1     | 10.1.0.4/30    |
| rr1 ↔ p2      | 10.1.0.8/30    |
| p1  ↔ p2      | 10.1.0.12/30   |
| p2  ↔ pe2     | 10.1.0.16/30   |
| pe2 ↔ ce2     | 192.168.20.0/30 |

---

## Troubleshooting: VRF not working

If the VRF CE-facing interface isn't in CUST-A after deploy, run manually:

```bash
# On pe1
sudo docker exec clab-mpls-sr-isis-bgp-pe1 bash -c "
  ip link add CUST-A type vrf table 100 2>/dev/null || true
  ip link set CUST-A up
  ip link set eth1 master CUST-A
  vtysh -b
"

# On pe2
sudo docker exec clab-mpls-sr-isis-bgp-pe2 bash -c "
  ip link add CUST-A type vrf table 100 2>/dev/null || true
  ip link set CUST-A up
  ip link set eth2 master CUST-A
  vtysh -b
"
```

## Troubleshooting: MPLS not forwarding

If `net.mpls.platform_labels` can't be set via exec, set it on the host:

```bash
sudo sysctl -w net.mpls.platform_labels=1048575
```
