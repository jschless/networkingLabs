# debug-dmvpn-phase1 — spoke1 isolated from DMVPN fabric; NHRP registration fails

## Scenario

A colleague deployed a DMVPN Phase 1 hub-and-spoke topology. spoke2 and spoke3 are fully functional — they register with the hub, OSPF adjacencies form, and LANs are reachable. spoke1, however, never appears in the NHRP registration table on the hub, its OSPF adjacency to the hub never forms, and its simulated LAN (192.168.1.0/24) is unreachable from the rest of the network.

## Topology

```
          [spoke1] WAN 10.0.0.11  tunnel 172.16.0.11  LAN 192.168.1.0/24
          [spoke2] WAN 10.0.0.12  tunnel 172.16.0.12  LAN 192.168.2.0/24  ──[br-wan]──[hub]
          [spoke3] WAN 10.0.0.13  tunnel 172.16.0.13  LAN 192.168.3.0/24
                                                               hub WAN 10.0.0.1  tunnel 172.16.0.1
```

## IP / Node Reference

| Node   | WAN IP (eth1)  | Tunnel IP (Tunnel0) | LAN (lo)       |
|--------|---------------|-------------------|----------------|
| hub    | 10.0.0.1/24   | 172.16.0.1/24     | 10.0.0.1/32    |
| spoke1 | 10.0.0.11/24  | 172.16.0.11/24    | 192.168.1.1/24 |
| spoke2 | 10.0.0.12/24  | 172.16.0.12/24    | 192.168.2.1/24 |
| spoke3 | 10.0.0.13/24  | 172.16.0.13/24    | 192.168.3.1/24 |

## Expected Behavior

- All spokes register with the hub via NHRP
- `show ip nhrp` on hub shows entries for 172.16.0.11, 172.16.0.12, 172.16.0.13
- OSPF adjacencies: hub ↔ spoke1, hub ↔ spoke2, hub ↔ spoke3 all reach Full state
- LAN-to-LAN reachability: 192.168.1.1 ↔ 192.168.2.1 ↔ 192.168.3.1 via OSPF

## Deploy & Access

```bash
sudo containerlab deploy -t topology.clab.yml

docker exec -it clab-debug-dmvpn-phase1-hub Cli
docker exec -it clab-debug-dmvpn-phase1-spoke1 Cli
docker exec -it clab-debug-dmvpn-phase1-spoke2 Cli
```

## Observed Symptoms

```
hub# show ip nhrp
172.16.0.12/32 via 172.16.0.12
   Type: dynamic  Flags: registered
   NBMA address: 10.0.0.12

172.16.0.13/32 via 172.16.0.13
   Type: dynamic  Flags: registered
   NBMA address: 10.0.0.13

(172.16.0.11 is MISSING — spoke1 never registered)

hub# show ip ospf neighbor
Neighbor ID     Pri State           Dead Time  Address        Interface
10.0.0.12         1 Full/-          00:01:58   172.16.0.12    Tunnel0
10.0.0.13         1 Full/-          00:01:47   172.16.0.13    Tunnel0

(spoke1 / 10.0.0.11 is MISSING from OSPF neighbors)

spoke1# show ip nhrp
(empty — no entries, no successful registration)

spoke2# ping 192.168.1.1
PING 192.168.1.1: 100% packet loss
```

## Your Task

Identify the misconfiguration on spoke1 using show commands. Do not look at config files yet — diagnose from symptoms first.

spoke2 and spoke3 work correctly. spoke1 has the same setup.sh and tunnel but its NHRP registration fails. What NHRP parameter controls where the spoke sends its registration request?

## Useful Show Commands

```
show ip nhrp
show ip nhrp nhs
show ip ospf neighbor
show ip ospf interface Tunnel0
show running-config
```

## Hints

<details><summary>Hint 1 — Where to start</summary>

NHRP registration is the first thing that must succeed before OSPF runs over the tunnel. Run `show ip nhrp` on spoke1 — if there are no entries, the registration to the NHS (Next Hop Server) failed. Compare `show ip nhrp nhs` on spoke1 vs spoke2 to see where each spoke is sending its registration.

</details>

<details><summary>Hint 2 — Narrowing it down</summary>

On spoke1, run `show running-config` and look at the `ip nhrp nhs` line under `interface Tunnel0`. On spoke2, do the same. The NHS address format is:

```
ip nhrp nhs <tunnel-overlay-IP> nbma <physical-WAN-IP>
```

What is the hub's tunnel IP? What is its WAN IP? Which one should appear as the NHS address?

</details>

<details><summary>Hint 3 — The specific problem</summary>

spoke1's config has `ip nhrp nhs 10.0.0.1 nbma 10.0.0.1` — both the NHS and NBMA are set to the hub's WAN IP (10.0.0.1). The NHS field must be the hub's **tunnel overlay IP** (172.16.0.1), not its WAN IP. The NBMA field correctly specifies the physical WAN address. spoke1 is trying to register with a non-existent NHRP server at overlay address 10.0.0.1.

</details>

## Solution

<details><summary>Fix (don't peek!)</summary>

On **spoke1** in Cli:

```
spoke1# configure terminal
spoke1(config)# interface Tunnel0
spoke1(config-if)# no ip nhrp nhs 10.0.0.1 nbma 10.0.0.1 multicast
spoke1(config-if)# no ip nhrp map 10.0.0.1 10.0.0.1
spoke1(config-if)# ip nhrp nhs 172.16.0.1 nbma 10.0.0.1 multicast
spoke1(config-if)# ip nhrp map 172.16.0.1 10.0.0.1
spoke1(config-if)# end
spoke1# write memory
```

</details>

## Verification

```
hub# show ip nhrp
172.16.0.11/32 via 172.16.0.11
   Type: dynamic  Flags: registered
   NBMA address: 10.0.0.11

172.16.0.12/32 via 172.16.0.12
   ...
172.16.0.13/32 via 172.16.0.13
   ...

hub# show ip ospf neighbor
Neighbor ID     Pri State    Dead Time  Address       Interface
10.0.0.11         1 Full/-   00:01:58   172.16.0.11   Tunnel0
10.0.0.12         1 Full/-   00:01:55   172.16.0.12   Tunnel0
10.0.0.13         1 Full/-   00:01:52   172.16.0.13   Tunnel0

spoke2# ping 192.168.1.1
64 bytes from 192.168.1.1: icmp_seq=1 ttl=63 time=1.2 ms
```
