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

- `ip vrf exec VRF-RED ping 10.10.0.1` from pe1 → succeeds (ce-a1 reachable)
- `ip vrf exec VRF-RED ping 10.10.0.2` from pe1 → succeeds (ce-a2 reachable)
- `ping 10.10.0.2 source 10.10.0.1` from ce-a1 → succeeds
- `ping 10.20.0.2 source 10.20.0.1` from ce-b1 → succeeds
- Customer A and Customer B are completely isolated from each other

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/debug-vrf-lite/topology.yml

docker exec -it clab-debug-vrf-lite-pe1  vtysh
docker exec -it clab-debug-vrf-lite-ce-a1 ping 10.10.0.2 -c3 -I 10.10.0.1
```

Wait ~10 seconds after deploy for FRR to initialize.

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
Codes: K - kernel route, C - connected ...

C>* 10.10.99.0/30 is directly connected, eth2
S   10.10.0.1/32 [1/0] via 10.10.12.1, eth1, inactive
S>* 10.10.0.2/32 [1/0] via 10.10.99.2, eth2
```

The 10.10.12.0/30 connected subnet is **absent** from VRF-RED. The static route
to ce-a1's loopback is marked **inactive** (next-hop 10.10.12.1 is unreachable
in VRF-RED).

---

## Your task

The VRF-RED routing table on pe1 is missing the 10.10.12.0/30 subnet — the link
to ce-a1. That subnet belongs to pe1's eth1 interface. Something about eth1's
VRF assignment is wrong.

Work through the diagnostic questions:
1. On pe1, run `show ip vrf` — which interfaces are listed under each VRF?
2. Under VRF-RED, which interfaces appear?
3. Under VRF-BLUE, which interfaces appear?
4. Should eth1 (10.10.12.2/30, Customer A) be in VRF-RED or VRF-BLUE?

---

## Useful show commands

```
! List VRFs and their member interfaces on pe1
show ip vrf

! Full routing table per VRF
show ip route vrf VRF-RED
show ip route vrf VRF-BLUE

! Ping within a specific VRF
ip vrf exec VRF-RED ping 10.10.12.1

! After fixing: verify pe1 can reach ce-a1 within VRF-RED
ip vrf exec VRF-RED ping 10.10.0.1
```

---

## Hints

<details>
<summary>Hint 1 — Where to start</summary>

On pe1, run:
```
show ip vrf
```

Look at the interface list under each VRF. You should see:
- VRF-RED: eth1 (to ce-a1), eth2 (inter-PE RED)
- VRF-BLUE: eth3 (to ce-b1), eth4 (inter-PE BLUE)

If eth1 (10.10.12.2) appears under VRF-BLUE instead of VRF-RED, that's the bug.

</details>

<details>
<summary>Hint 2 — Narrowing it down</summary>

On pe1, run:
```
show ip route vrf VRF-RED
```

If 10.10.12.0/30 (the ce-a1 link subnet) is missing from the connected routes,
it means eth1 is NOT in VRF-RED. Check VRF-BLUE:

```
show ip route vrf VRF-BLUE
```

If 10.10.12.0/30 appears in VRF-BLUE's connected routes, eth1 has been placed
in the wrong VRF.

</details>

<details>
<summary>Hint 3 — The specific problem</summary>

pe1's frr.conf has `interface eth1 vrf VRF-BLUE` instead of `interface eth1 vrf VRF-RED`.
eth1 is the link to ce-a1 (Customer A), which must be in VRF-RED. Instead it's in
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
pe1(config)# no interface eth1 vrf VRF-BLUE
pe1(config)# interface eth1 vrf VRF-RED
pe1(config-if)# ip address 10.10.12.2/30
pe1(config-if)# description to ce-a1 (RED)
pe1(config-if)# end
pe1# write memory
```

FRR will move the interface to VRF-RED. The static route to ce-a1's loopback
will become active as 10.10.12.1 becomes reachable in VRF-RED.

</details>

---

## Verification

After applying the fix:

```
! On pe1 — eth1 should now appear under VRF-RED
show ip vrf

! On pe1 — 10.10.12.0/30 should now be connected in VRF-RED
show ip route vrf VRF-RED

! On pe1 — ping ce-a1 within VRF-RED
ip vrf exec VRF-RED ping 10.10.0.1

! End-to-end Customer A reachability
ce-a1# ping 10.10.0.2 source 10.10.0.1
```

Expected on pe1 after fix:
```
pe1# show ip route vrf VRF-RED
C>* 10.10.12.0/30 is directly connected, eth1
C>* 10.10.99.0/30 is directly connected, eth2
S>* 10.10.0.1/32 [1/0] via 10.10.12.1, eth1
S>* 10.10.0.2/32 [1/0] via 10.10.99.2, eth2
```

Both Customer A loopbacks reachable. VRF-BLUE unaffected — Customer B still works.
