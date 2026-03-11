# debug-vrf-lite — Interface Assigned to Wrong VRF

## Scenario

A VRF-Lite network serves two customers: Customer A (VRF-RED) and Customer B
(VRF-BLUE). pe1 and pe2 each have dedicated interfaces per VRF, with separate
inter-PE links for isolation. ce-b1 can reach ce-b2 fine, but ce-a1 cannot reach
ce-a2. The PE nodes and CE nodes all have their configs in place.

A junior engineer recently "cleaned up" the pe1 configuration and may have
accidentally moved an interface to the wrong VRF.

Your job: deploy the lab, use show commands to find the fault, and fix it.
**Do not look at the config files yet** — diagnose from symptoms first.

---

## Topology

```
[ce-a1] --RED-- [pe1] --RED-- [pe2] --RED-- [ce-a2]
[ce-b1] --BLUE- [pe1] --BLUE- [pe2] --BLUE- [ce-b2]
```

| Node | IP / Loopback | VRF |
|------|---------------|-----|
| ce-a1 | eth1=10.10.12.1/30, lo=10.10.0.1/32 | — (customer A) |
| pe1   | eth1=10.10.12.2/30, eth2=10.10.99.1/30, eth3=10.20.12.2/30, eth4=10.20.99.1/30 | RED+BLUE |
| pe2   | eth1=10.10.99.2/30, eth2=10.10.34.1/30, eth3=10.20.99.2/30, eth4=10.20.34.1/30 | RED+BLUE |
| ce-a2 | eth1=10.10.34.2/30, lo=10.10.0.2/32 | — (customer A) |
| ce-b1 | eth1=10.20.12.1/30, lo=10.20.0.1/32 | — (customer B) |
| ce-b2 | eth1=10.20.34.2/30, lo=10.20.0.2/32 | — (customer B) |

---

## Expected behavior (when healthy)

- `ping vrf VRF-RED 10.10.0.1` from pe1 → succeeds (ce-a1 reachable)
- `ping vrf VRF-RED 10.10.0.2` from pe1 → succeeds (ce-a2 reachable)
- `ping 10.10.0.2 source 10.10.0.1` from ce-a1 → succeeds
- `ping 10.20.0.2 source 10.20.0.1` from ce-b1 → succeeds
- Customer A and Customer B are completely isolated from each other

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/debug-vrf-lite/topology.clab.yml

docker exec -it clab-debug-vrf-lite-pe1  Cli
docker exec -it clab-debug-vrf-lite-ce-a1 Cli
```

---

## Observed symptoms

**Customer A ping fails:**
```
ce-a1# ping 10.10.0.2 source 10.10.0.1
PING 10.10.0.2 (10.10.0.2): 56 data bytes
^C
5 packets transmitted, 0 received, 100% packet loss
```

**Customer B ping succeeds (VRF-BLUE is unaffected):**
```
ce-b1# ping 10.20.0.2 source 10.20.0.1
PING 10.20.0.2: 56 data bytes
5 packets transmitted, 5 received, 0% packet loss
```

**On pe1 — VRF-RED routing table is incomplete:**
```
pe1# show ip route vrf VRF-RED

VRF: VRF-RED
 C        10.10.99.0/30 is directly connected, Ethernet2
 S        10.10.0.1/32 [1/0] via 10.10.12.1, Ethernet1 [inactive]
 S        10.10.0.2/32 [1/0] via 10.10.99.2, Ethernet2
```

The 10.10.12.0/30 connected subnet is **absent** from VRF-RED. The static route
to ce-a1's loopback is **inactive** (next-hop 10.10.12.1 is unreachable in VRF-RED).

---

## Your task

The VRF-RED routing table on pe1 is missing the 10.10.12.0/30 subnet — the link
to ce-a1. That subnet belongs to pe1's Ethernet1 interface. Something about
Ethernet1's VRF assignment is wrong.

Work through the diagnostic questions:
1. On pe1, run `show vrf` — which interfaces are listed under each VRF?
2. Under VRF-RED, which interfaces appear?
3. Under VRF-BLUE, which interfaces appear?
4. Should Ethernet1 (10.10.12.2/30, Customer A) be in VRF-RED or VRF-BLUE?

---

## Useful show commands

```
! List VRFs and their member interfaces on pe1
pe1# show vrf

! Full routing table per VRF
pe1# show ip route vrf VRF-RED
pe1# show ip route vrf VRF-BLUE

! Ping within a specific VRF
pe1# ping vrf VRF-RED 10.10.12.1

! After fixing: verify pe1 can reach ce-a1 within VRF-RED
pe1# ping vrf VRF-RED 10.10.0.1
```

---

## Hints

<details>
<summary>Hint 1 — Where to start</summary>

On pe1, run:
```
show vrf
```

Look at the interface list under each VRF. You should see:
- VRF-RED: Ethernet1 (to ce-a1), Ethernet2 (inter-PE RED)
- VRF-BLUE: Ethernet3 (to ce-b1), Ethernet4 (inter-PE BLUE)

If Ethernet1 (10.10.12.2) appears under VRF-BLUE instead of VRF-RED, that's the bug.

</details>

<details>
<summary>Hint 2 — Narrowing it down</summary>

On pe1, run:
```
show ip route vrf VRF-RED
```

If 10.10.12.0/30 (the ce-a1 link subnet) is missing from the connected routes,
it means Ethernet1 is NOT in VRF-RED. Check VRF-BLUE:

```
show ip route vrf VRF-BLUE
```

If 10.10.12.0/30 appears in VRF-BLUE's connected routes, Ethernet1 has been placed
in the wrong VRF.

</details>

<details>
<summary>Hint 3 — The specific problem</summary>

pe1's startup-config has `vrf VRF-BLUE` under `interface Ethernet1` instead of `vrf VRF-RED`.
Ethernet1 is the link to ce-a1 (Customer A), which must be in VRF-RED. Instead it's in
VRF-BLUE, putting a Customer A link into Customer B's VRF. The 10.10.12.0/30 subnet
shows up under VRF-BLUE, and the VRF-RED static route to ce-a1's loopback is inactive.

</details>

---

## Solution

<details>
<summary>Fix (don't peek until you've tried the hints)</summary>

On **pe1**:

```
pe1# configure terminal
pe1(config)# interface Ethernet1
pe1(config-if)# vrf VRF-RED
pe1(config-if)# ip address 10.10.12.2/30
pe1(config-if)# end
```

When you change a VRF assignment in EOS, the existing IP address is cleared.
Re-enter `ip address 10.10.12.2/30` after setting the new VRF.

EOS will move Ethernet1 from VRF-BLUE to VRF-RED. The static route to ce-a1's loopback
will become active as 10.10.12.1 becomes reachable in VRF-RED.

</details>

---

## Verification

After applying the fix:

```
! On pe1 — Ethernet1 should now appear under VRF-RED
pe1# show vrf

! On pe1 — 10.10.12.0/30 should now be connected in VRF-RED
pe1# show ip route vrf VRF-RED

! On pe1 — ping ce-a1 within VRF-RED
pe1# ping vrf VRF-RED 10.10.0.1

! End-to-end Customer A reachability
ce-a1# ping 10.10.0.2 source 10.10.0.1
```

Expected on pe1 after fix:
```
pe1# show ip route vrf VRF-RED

VRF: VRF-RED
 C        10.10.12.0/30 is directly connected, Ethernet1
 C        10.10.99.0/30 is directly connected, Ethernet2
 S        10.10.0.1/32 [1/0] via 10.10.12.1, Ethernet1
 S        10.10.0.2/32 [1/0] via 10.10.99.2, Ethernet2
```

Both Customer A loopbacks reachable. VRF-BLUE unaffected — Customer B still works.
