# debug-ospf-auth — Broken OSPF MD5 Authentication

Your network team recently rotated the OSPF MD5 authentication keys across
all three routers. The junior engineer ran the change during a maintenance
window and reported "all done." This morning, users at the r1 site report
intermittent connectivity issues. r3 seems fine but r1 is unreachable from
the rest of the network.

Your job: deploy the lab, use show commands to find the fault, and fix it.
**Do not look at the config files yet** — diagnose from symptoms first.

---

## Topology

```
  [r1] --Area 0-- [r2] --Area 0-- [r3]
```

### Link addressing

| Link    | Subnet        | Left           | Right          |
|---------|---------------|----------------|----------------|
| r1 — r2 | 10.1.12.0/30  | 10.1.12.1 (r1) | 10.1.12.2 (r2) |
| r2 — r3 | 10.1.23.0/30  | 10.1.23.1 (r2) | 10.1.23.2 (r3) |

| Node | Loopback    | Area   |
|------|-------------|--------|
| r1   | 10.0.0.1/32 | Area 0 |
| r2   | 10.0.0.2/32 | Area 0 |
| r3   | 10.0.0.3/32 | Area 0 |

---

## Expected behavior (when healthy)

- Both adjacencies (r1–r2, r2–r3) in **Full** state
- r1 can `ping 10.0.0.3 source 10.0.0.1` successfully
- All three loopbacks reachable from any router

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/debug-ospf-auth/topology.yml

docker exec -it clab-debug-ospf-auth-r1 vtysh
docker exec -it clab-debug-ospf-auth-r2 vtysh
```

Wait ~15 seconds after deploy for OSPF to attempt adjacency formation.

---

## Observed symptoms

**On r2:**
```
r2# show ip ospf neighbor
Neighbor ID     Pri State           Up Time         Dead Time Address         Interface
10.0.0.3          1 Full/DR         1m03s             37.421s 10.1.23.2       eth2:10.1.23.1
```

Only r3 is present. r1 is completely absent.

**On r1:**
```
r1# show ip ospf neighbor
(no output)
```

**End-to-end:**
```
r1# ping 10.0.0.3 source 10.0.0.1
PING 10.0.0.3 (10.0.0.3): 56 data bytes
^C
--- 10.0.0.3 ping statistics ---
5 packets transmitted, 0 received, 100% packet loss
```

r1 is completely isolated. The r2–r3 adjacency is healthy. The fault is
localized to the r1–r2 link.

---

## Your task

OSPF MD5 authentication is configured on all interfaces. Both r1 and r2
should have matching key configurations on their shared link. Something
differs between what r1 has and what r2 has on that link.

Work through the diagnostic questions:
1. What does `show ip ospf interface eth1` say about auth type and key IDs on r1?
2. What does `show ip ospf interface eth1` say on r2?
3. The auth type and key ID look the same — so what else could cause the failure?
4. Where would you look for clues in the FRR logs?

---

## Useful show commands

```
! Check adjacency state — who is present and in what state?
show ip ospf neighbor

! Check auth type, key ID, and cryptographic sequence on an interface
show ip ospf interface eth1

! FRR log — authentication failure messages appear here
! Run from a bash shell, not vtysh:
!   docker exec clab-debug-ospf-auth-r2 tail -30 /var/log/frr/frr.log
```

---

## Hints

<details>
<summary>Hint 1 — Where to start</summary>

Run `show ip ospf interface eth1` on both r1 and r2. Compare the output.
Pay attention to:
- Authentication type (should say `MD5`)
- Key ID in use (should match on both sides)

If both look identical in auth type and key ID, the only remaining variable
is the actual key *value*, which show commands don't reveal.

</details>

<details>
<summary>Hint 2 — Narrowing it down</summary>

Check FRR's log on r2 for authentication failure messages:

```bash
docker exec clab-debug-ospf-auth-r2 tail -30 /var/log/frr/frr.log
```

You should see lines like:
```
OSPF: Rcv pkt from 10.1.12.1 : MD5 authentication failed
```

This confirms: r2 is receiving OSPF packets from r1 (so the link is up),
but the MD5 digest is wrong. The key value on one side doesn't match.

Since r2–r3 is fine, the mismatch is on r2's eth1 key (not eth2).

</details>

<details>
<summary>Hint 3 — The specific problem</summary>

r2's eth1 is configured with key `"SecretKey321"` (digits reversed) instead
of `"SecretKey123"`. r1 and r3 both have the correct key. The key rotation
script transposed the digits on r2's eth1 only.

</details>

---

## Solution

<details>
<summary>Fix (don't peek until you've tried the hints)</summary>

On **r2**:

```
r2# configure terminal
r2(config)# interface eth1
r2(config-if)# ip ospf message-digest-key 1 md5 SecretKey123
r2(config-if)# end
r2# write memory
```

This overwrites the wrong key value with the correct one. FRR replaces the
key in-place when you configure the same key ID — no need to remove it first.

The r1–r2 adjacency will re-establish within seconds once the digests match.

</details>

---

## Verification

After applying the fix:

```
! On r2 — both neighbors should now be Full
show ip ospf neighbor

! End-to-end reachability restored
r1# ping 10.0.0.3 source 10.0.0.1
```

Expected:
```
r2# show ip ospf neighbor
Neighbor ID     Pri State           Up Time         Dead Time Address         Interface
10.0.0.1          1 Full/BDR        0m08s             38.210s 10.1.12.1       eth1:10.1.12.2
10.0.0.3          1 Full/DR         4m21s             35.614s 10.1.23.2       eth2:10.1.23.1
```

Both adjacencies Full — all loopbacks reachable.
