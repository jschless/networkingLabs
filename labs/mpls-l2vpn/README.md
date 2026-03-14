# MPLS L2VPN Lab

This lab teaches **MPLS Layer 2 VPN services** — specifically the pseudowire (VPWS)
model where a service provider carries customer Ethernet frames transparently over
an MPLS core. From the customer's perspective, ce1 and ce2 are on the same Ethernet
segment even though they are separated by three MPLS routers.

## Background: L2VPN vs L3VPN

| Aspect | L3VPN (e.g., mpls-sr-isis-bgp lab) | L2VPN / Pseudowire (this lab) |
|---|---|---|
| What is tunnelled? | IP packets (Layer 3) | Ethernet frames (Layer 2) |
| CE needs routing? | Yes (eBGP to PE) | No — CE just has an IP address |
| PE terminates L3? | Yes — PE is the CE's next-hop | No — PE is transparent to CE |
| CE subnet isolation? | Yes — different VRFs, different subnets | No — same subnet across sites |
| Use case | Enterprise WAN, carrier IP-VPN | Leased line replacement, carrier Ethernet |

In this lab, **ce1 and ce2 share subnet 10.100.0.0/24** and communicate via
ARP and direct L2 forwarding — just like hosts on the same switch.

## Topology

```
[ce1]──eth1──[pe1]──eth2──[p1]──eth2──[pe2]──eth2──[ce2]
             10.0.0.1          10.0.0.2         10.0.0.3
             (PE)               (P)               (PE)
```

### MPLS core addressing

| Link | pe1 side | p1 side | pe2 side |
|---|---|---|---|
| pe1 eth2 — p1 eth1 | 10.1.0.1/30 | 10.1.0.2/30 | — |
| p1 eth2 — pe2 eth1 | — | 10.1.0.5/30 | 10.1.0.6/30 |
| Loopback | 10.0.0.1/32 | 10.0.0.2/32 | 10.0.0.3/32 |

### CE addressing (same subnet — they share an L2 domain)

| Node | Interface | Address |
|---|---|---|
| ce1 | eth1 | 10.100.0.1/24 |
| ce2 | eth1 | 10.100.0.2/24 |

### L2VPN attachment circuits (no IP on PE side)

- `ce1:eth1` ↔ `pe1:eth1`
- `ce2:eth1` ↔ `pe2:eth2`

## How the pseudowire works

```
ce1                pe1                   p1                  pe2              ce2
 |                  |                     |                    |                |
 |  Ethernet frame  |                     |                    |                |
 |─────────────────>|                     |                    |                |
 |                  | Push MPLS labels:   |                    |                |
 |                  | [PW-label|IGP-label]|                    |                |
 |                  |────────────────────>|                    |                |
 |                  |                     | Swap IGP label     |                |
 |                  |                     |───────────────────>|                |
 |                  |                     |                    | Pop labels     |
 |                  |                     |                    | Forward frame  |
 |                  |                     |                    |───────────────>|
```

**Two labels are used (label stacking):**

1. **IGP/transport label** — assigned by LDP for the pe2 loopback prefix (10.0.0.3/32).
   p1 swaps this label to forward the packet toward pe2. This is the outer label.

2. **PW label (VC label)** — assigned by pe2 via targeted LDP for PW-ID 100.
   pe1 pushes this as the inner label. pe2 recognises it and knows which bridge
   to deliver the frame to. This is the inner label.

**Targeted LDP session:** pe1 and pe2 establish a *targeted* LDP session (unicast
hellos over the transport address) to exchange PW labels. This session goes over
the MPLS core using the transport labels distributed by the normal link LDP sessions.

**Linux bridge on PE:** each PE has a Linux bridge `br-l2vpn` connecting:
- The CE-facing attachment circuit (`eth1` on pe1, `eth2` on pe2)
- A pseudowire dummy interface (`pw0`) representing the MPLS tunnel endpoint

Once LDP negotiates the PW labels, FRR/zebra programs kernel MPLS forwarding so
that frames entering `pw0` get encapsulated and frames arriving with the PW label
are decapsulated and delivered to `pw0` (and thus to the bridge and out to the CE).

## Signaling: LDP vs BGP VPLS

| Signaling | Standard | FRR support | Notes |
|---|---|---|---|
| LDP FEC 128 (VPWS) | RFC 4447 | Yes (ldpd) | This lab — point-to-point PW |
| LDP FEC 129 (VPLS) | RFC 4762 | Partial | Requires BGP autodiscovery |
| BGP VPLS | RFC 4761 | Partial | BGP `address-family l2vpn vpls` |
| BGP EVPN VPLS | RFC 7432 | Yes (bgpd) | Used in EVPN labs |

This lab uses **LDP FEC 128 (VPWS)** — the simplest and most widely deployed form.

---

## Deploy

```bash
# Build the FRR image first (if not already done)
docker build -t frr-lab:local images/frr/

# Deploy
sudo containerlab deploy -t labs/mpls-l2vpn/topology.clab.yml

# Or using the helper script
./scripts/lab.sh deploy mpls-l2vpn
```

## Accessing nodes

```bash
# FRR CLI on PE/P nodes
./scripts/lab.sh vtysh mpls-l2vpn pe1
./scripts/lab.sh vtysh mpls-l2vpn p1
./scripts/lab.sh vtysh mpls-l2vpn pe2

# Shell on CE nodes (no FRR, just Linux)
./scripts/lab.sh bash mpls-l2vpn ce1
./scripts/lab.sh bash mpls-l2vpn ce2

# Shell on PE nodes (to inspect bridges, MPLS tables)
./scripts/lab.sh bash mpls-l2vpn pe1
```

---

## Task 1: Verify the MPLS core (IS-IS + LDP)

Before the pseudowire can work, the MPLS core must be healthy.

### 1a. Check IS-IS adjacencies

On pe1:
```
show isis neighbor
```
Expected: p1 listed as neighbor, state UP.

On p1:
```
show isis neighbor
```
Expected: pe1 and pe2 both listed as neighbors, state UP.

### 1b. Check IS-IS routing table

On pe1:
```
show isis route
```
Expected: routes to 10.0.0.2/32 (p1) and 10.0.0.3/32 (pe2) visible.

### 1c. Check LDP link sessions

On pe1:
```
show mpls ldp neighbor
```
Expected: LDP peer 10.0.0.2 (p1) shown with session state OPERATIONAL.

On p1:
```
show mpls ldp neighbor
```
Expected: LDP peers 10.0.0.1 (pe1) and 10.0.0.3 (pe2) both OPERATIONAL.

### 1d. Check MPLS forwarding table (IGP transport labels)

On pe1:
```
show mpls table
```
Expected: entries for pe2's loopback (10.0.0.3/32) with an outgoing label via p1.

On p1:
```
show mpls table
```
Expected: swap entries forwarding toward both pe1 and pe2.

---

## Task 2: Verify targeted LDP and pseudowire negotiation

The pseudowire requires a *targeted* LDP session between pe1 and pe2.

### 2a. Check targeted LDP session

On pe1:
```
show mpls ldp neighbor
```
Look for a peer entry for **10.0.0.3** (pe2) with session type `Targeted`.
This session DOES NOT require a direct link — it uses the MPLS core as transport.

On pe2:
```
show mpls ldp neighbor
```
Look for a peer entry for **10.0.0.1** (pe1) with session type `Targeted`.

### 2b. Check LDP pseudowires

On pe1:
```
show mpls ldp pseudowires
```
Expected output (indicative):
```
Pseudowire    Peer             PW-ID  Local Label  Remote Label  Status
------------  ---------------  -----  -----------  ------------  ------
pw-to-pe2     10.0.0.3         100    524289        524290        UP
```

The `Local Label` is what pe2 will push when sending frames to pe1.
The `Remote Label` is what pe1 pushes when sending frames to pe2.

### 2c. Confirm MPLS label stack

On pe1 (bash shell):
```bash
ip -M route show
```
or in FRR vtysh:
```
show mpls table
```
Look for an entry with the PW remote label pushing into the outgoing label (IGP label for 10.0.0.3/32).

---

## Task 3: Verify the Linux bridge (PE data plane)

The data plane uses the Linux bridge `br-l2vpn` on each PE.

### 3a. Check bridge membership on pe1 (bash shell)

```bash
bridge link show
```
Expected: `eth1` and `pw0` both enslaved to `br-l2vpn`.

```bash
ip link show br-l2vpn
ip link show pw0
ip link show eth1
```

### 3b. Observe the bridge MAC table

Before any traffic, the MAC table is empty:
```bash
bridge fdb show dev br-l2vpn
```

After ce1 sends traffic (ARP), ce1's MAC should appear:
```bash
bridge fdb show dev br-l2vpn
```

---

## Task 4: Test end-to-end L2 connectivity

This is the payoff — ce1 and ce2 behave as if on the same Ethernet switch.

### 4a. Ping from ce1 to ce2

```bash
# On ce1
ping 10.100.0.2
```

Expected: successful ping. The first ping may be slightly slower (ARP resolution),
but subsequent pings should be fast.

**What is happening underneath:**
1. ce1 sends ARP: "Who has 10.100.0.2? Tell 10.100.0.1"
2. ARP frame goes: ce1 → pe1:eth1 → br-l2vpn → pw0 → MPLS encap → pe2 → br-l2vpn → pe2:eth2 → ce2
3. ce2 replies with ARP. The reply traverses the same path in reverse.
4. ce1 now knows ce2's MAC and sends ICMP echo directly.

### 4b. Ping from ce2 to ce1

```bash
# On ce2
ping 10.100.0.1
```

### 4c. Verify ARP resolution

```bash
# On ce1 — after pinging, ce2's MAC should be in ARP cache
ip neigh show
```

```bash
# On ce2
ip neigh show
```

### 4d. Observe MAC learning on the bridge

After traffic, run on pe1 bash shell:
```bash
bridge fdb show dev br-l2vpn
```
You should see MAC addresses for both ce1 and ce2 learned on the bridge.

---

## Task 5: Observe MPLS label stacking in action

Use tcpdump/tshark to see the label stack on the MPLS core link.

```bash
# Capture on pe1 eth2 (core-facing link toward p1) while pinging
./scripts/lab.sh capture mpls-l2vpn pe1 eth2
```

In another terminal, trigger traffic:
```bash
./scripts/lab.sh bash mpls-l2vpn ce1
# ping 10.100.0.2
```

In the capture you should see:
- MPLS packets with 2 labels (label stack)
- Inner label = PW VC label
- Outer label = IGP transport label for pe2

Compare with p1's traffic (only 1 label after p1 swaps the outer label):
```bash
./scripts/lab.sh capture mpls-l2vpn p1 eth2
```

---

## Task 6: Explore VPLS extension (multi-point)

**VPLS (Virtual Private LAN Service)** extends VPWS to a multipoint service:
instead of one pseudowire, the PE maintains a *full mesh* of pseudowires to all
remote PEs in the same VPLS instance, and uses MAC learning on the bridge to
decide which PW to use for forwarding.

To experiment with a third CE site, you could add:
- A third PE router (pe3) with its own LDP pseudowire to both pe1 and pe2
- A third CE (ce3) attached to pe3
- pe1 and pe2 each need an additional `member pseudowire` in the l2vpn stanza

The Linux bridge on each PE naturally handles the VPLS MAC learning — frames
arriving on any PW are flooded to all other bridge ports (CE ports + remaining PWs)
until the MAC is learned.

> **Note:** Full mesh of PWs requires N×(N-1)/2 targeted LDP sessions. For large
> VPLS deployments (many PE nodes), BGP-based autodiscovery (RFC 4761 or RFC 6074)
> is used to avoid manual PW configuration.

---

## Show commands reference

### IS-IS

```
show isis neighbor              # IS-IS adjacency table
show isis route                 # IS-IS RIB (with MPLS labels if SR enabled)
show isis database              # link-state database
```

### LDP

```
show mpls ldp neighbor          # all LDP sessions (link + targeted)
show mpls ldp neighbor detail   # detailed session info including capabilities
show mpls ldp pseudowires       # pseudowire status and labels
show mpls ldp binding           # label bindings (local + remote)
show mpls ldp binding detail    # per-prefix detail
show mpls ldp discovery         # hello adjacencies
```

### MPLS forwarding

```
show mpls table                 # kernel MPLS forwarding table (zebra view)
show mpls fec                   # FEC to label mappings
```

### Linux bridge and MPLS (bash shell)

```bash
bridge link show                # which interfaces are in which bridges
bridge fdb show                 # MAC forwarding database
ip -M route show                # kernel MPLS routes (label→action mappings)
ip link show type bridge        # all bridge interfaces
ip link show master br-l2vpn   # interfaces enslaved to br-l2vpn
```

---

## Key concepts

### Attachment Circuit (AC)
The physical or logical interface on the PE that connects to the customer CE.
In this lab: `pe1:eth1` (connected to ce1) and `pe2:eth2` (connected to ce2).
The AC carries raw L2 frames with no IP processing by the PE.

### Pseudowire (PW)
The logical tunnel across the MPLS core that carries L2 frames between two PE
attachment circuits. The PW is identified by:
- **Sender PE loopback** (e.g., 10.0.0.1 for pe1)
- **Receiver PE loopback** (e.g., 10.0.0.3 for pe2)
- **PW-ID** (100 in this lab)

### VC label (PW label / inner label)
A label negotiated by the targeted LDP session, specific to the pseudowire.
The receiving PE uses it to identify which bridge (VPLS instance) to deliver
the frame to. This is the inner label in the stack.

### Transport label (outer label)
The IGP label distributed by LDP link sessions across the core, used to forward
the encapsulated PW packet toward the remote PE. p1 performs a label swap on this.

### Targeted LDP
A special LDP session between two PEs that do not share a direct link.
Hellos are unicast (not multicast), and the session is established over the
MPLS transport network. Required for PW label negotiation.

### FEC 128
The IETF term for a point-to-point pseudowire with a manually configured
sender ID, receiver ID, and PW-ID. "FEC 128" refers to the LDP TLV type
used to advertise the PW label binding.

---

## Troubleshooting

### LDP sessions not forming

1. Check IS-IS is up first — LDP needs IGP reachability to the remote transport address:
   ```
   show isis neighbor
   show ip route 10.0.0.3/32   (on pe1 — should show via p1)
   ```

2. Check LDP is enabled on the core interface:
   ```
   show mpls ldp discovery       # should list eth2 as active discovery interface
   ```

3. Check targeted hello is configured and accepted:
   ```
   show mpls ldp neighbor       # look for 10.0.0.3 with Targeted session
   show mpls ldp discovery      # look for targeted hello to 10.0.0.3
   ```

4. Verify MPLS is enabled on core interfaces:
   ```
   show interface eth2           # look for "MPLS enabled"
   ```

### Pseudowire shows "down" or no labels

1. Verify targeted LDP session is OPERATIONAL:
   ```
   show mpls ldp neighbor detail
   ```

2. Check the l2vpn stanza parsed correctly:
   ```
   show running-config
   ```
   Look for the `l2vpn VPWS-CUST` block with `neighbor lsr-id` and `pw-id`.

3. Check MPLS label table for PW label entries:
   ```
   show mpls table
   ```

### Ping fails between ce1 and ce2

1. Check the bridge is up on both PEs (bash shell):
   ```bash
   ip link show br-l2vpn
   bridge link show
   ```

2. Check eth1/eth2 (CE port) is enslaved to br-l2vpn:
   ```bash
   ip link show master br-l2vpn
   ```

3. Capture ARP on pe1 eth1 to see if ce1 is sending ARPs:
   ```bash
   ./scripts/lab.sh capture mpls-l2vpn pe1 eth1
   ```
   Then ping from ce1. You should see ARP requests.

4. If ARP requests are seen on pe1:eth1 but not pe2:eth2, the pseudowire data
   plane is not forwarding. Check PW label and kernel MPLS routes:
   ```bash
   ip -M route show
   ```

### "Cannot find interface" errors in FRR

If FRR starts before setup.sh creates the bridge, some interfaces may be missing.
The `exec: - bash /setup.sh` in topology.clab.yml runs after container start,
and `vtysh -b` at the end of setup.sh reloads FRR config after the bridge exists.
If issues persist, manually run `vtysh -b` inside the container.

---

## Destroy

```bash
sudo containerlab destroy -t labs/mpls-l2vpn/topology.clab.yml --cleanup
# or
./scripts/lab.sh destroy mpls-l2vpn
```
