# GRE Basics — Practice Lab

Create a GRE point-to-point tunnel between two gateway routers across a simulated WAN. Route traffic between private LANs through the tunnel. Physical IP addressing is pre-configured — you build the tunnel and add routing.

---

## Topology

```
[host-a] --- [gw-a] ---WAN--- [internet] ---WAN--- [gw-b] --- [host-b]
 LAN A         |    203.0.113.0/30   203.0.113.4/30   |         LAN B
          tun0: 172.16.0.1                        tun0: 172.16.0.2
```

### Physical links (pre-configured)

| Link              | Subnet          | Left          | Right         |
|-------------------|-----------------|---------------|---------------|
| host-a — gw-a     | 192.168.1.0/24  | 192.168.1.10  | 192.168.1.1   |
| gw-a — internet   | 203.0.113.0/30  | 203.0.113.1   | 203.0.113.2   |
| internet — gw-b   | 203.0.113.4/30  | 203.0.113.5   | 203.0.113.6   |
| gw-b — host-b     | 192.168.2.0/24  | 192.168.2.1   | 192.168.2.10  |

### GRE tunnel (you create this)

| Parameter       | gw-a         | gw-b         |
|-----------------|--------------|--------------|
| Tunnel local    | 203.0.113.1  | 203.0.113.6  |
| Tunnel remote   | 203.0.113.6  | 203.0.113.1  |
| Tunnel IP       | 172.16.0.1/30| 172.16.0.2/30|
| Interface name  | tun0         | tun0         |

---

## Deploy and access

```bash
sudo containerlab deploy --topo topology.yml

# Bash shell (for ip tunnel commands)
docker exec -it clab-gre-basics-gw-a bash

# FRR CLI (for routing config)
docker exec -it clab-gre-basics-gw-a vtysh
```

---

## Step 1 — Verify baseline WAN reachability

Before creating the tunnel, confirm gw-a can reach gw-b over the WAN:

```bash
docker exec -it clab-gre-basics-gw-a bash
ping 203.0.113.6 -c 3
```

This should succeed — the internet router forwards between the two WAN subnets. If this fails, the tunnel cannot work either.

Also confirm that host-to-host traffic fails without the tunnel:
```bash
docker exec -it clab-gre-basics-host-a bash
ping 192.168.2.10 -c 3    # should FAIL — no route to LAN B
```

---

## Step 2 — Create the GRE tunnel on gw-a

Open a bash shell on gw-a:
```bash
docker exec -it clab-gre-basics-gw-a bash
```

Create the tunnel interface:
```bash
ip tunnel add tun0 mode gre local 203.0.113.1 remote 203.0.113.6 ttl 255
ip link set tun0 up
ip addr add 172.16.0.1/30 dev tun0
```

Verify the tunnel interface exists:
```bash
ip addr show tun0
ip tunnel show tun0
```

---

## Step 3 — Create the GRE tunnel on gw-b

```bash
docker exec -it clab-gre-basics-gw-b bash

ip tunnel add tun0 mode gre local 203.0.113.6 remote 203.0.113.1 ttl 255
ip link set tun0 up
ip addr add 172.16.0.2/30 dev tun0
```

Test the tunnel endpoint reachability:
```bash
ping 172.16.0.1 -c 3   # from gw-b, should reach gw-a's tunnel IP
```

---

## Step 4 — Add static routes through the tunnel

In vtysh on **gw-a**:
```
ip route 192.168.2.0/24 172.16.0.2
```

In vtysh on **gw-b**:
```
ip route 192.168.1.0/24 172.16.0.1
```

---

## Step 5 — Verify end-to-end

```bash
# From host-a
docker exec -it clab-gre-basics-host-a bash
ping 192.168.2.10 -c 3    # should now SUCCEED

# Traceroute to see the tunnel path
traceroute 192.168.2.10
# Path: 192.168.1.1 (gw-a LAN) -> 192.168.2.10 (host-b)
# The WAN hops are invisible — traffic is tunnelled!
```

---

## Experiment A — OSPF over GRE

Replace static routes with OSPF running directly over the tunnel. This is common when you want dynamic routing across a WAN.

Remove the static LAN routes first (`no ip route 192.168.x.0/24 ...`), then add OSPF to gw-a (in vtysh). The tunnel interface must be configured as point-to-point (GRE is a point-to-point medium):

```
interface tun0
 ip ospf area 0
 ip ospf network point-to-point
!
interface eth1
 ip ospf area 0
 ip ospf passive
!
router ospf
 ospf router-id 10.0.0.1
```

Mirror on gw-b (router-id 10.0.0.2).

Check adjacency: `show ip ospf neighbor` — tun0 should show `Full/  -`.

> **Warning — do not use `redistribute connected` here.** It will leak the WAN subnets (203.0.113.0/30, 203.0.113.4/30) into OSPF. The remote gateway will learn a route to the tunnel endpoint's WAN IP *via the tunnel*, creating a recursive routing loop that breaks the tunnel. The `ip ospf area 0` statement on the LAN interface already handles LAN advertisement — no redistribution is needed.

---

## Experiment B — The recursive routing pitfall

This demonstrates a common GRE misconfiguration: accidentally routing the tunnel DESTINATION through the tunnel itself.

On gw-a, add a bad route:
```
ip route 203.0.113.6/32 172.16.0.2
```

This tells gw-a "to reach gw-b's WAN IP, go through the tunnel." But the tunnel endpoint IS gw-b's WAN IP — creating an infinite loop. The tunnel interface will flap and traffic will fail.

Fix: always route the tunnel endpoint via the physical interface:
```
no ip route 203.0.113.6/32 172.16.0.2
ip route 203.0.113.6/32 203.0.113.2
```

The specific /32 host route for the remote tunnel endpoint must go out the physical interface, not the tunnel.

---

## Troubleshooting

**Tunnel interface created but ping across it fails**
- `ip tunnel show tun0` — verify local/remote IPs are correct
- `ping 203.0.113.6` from gw-a — confirm physical WAN reachability first
- `tcpdump -i eth2 proto gre` on gw-a — check if GRE packets are being sent

**Routes installed but traffic not flowing**
- The tunnel persists only until the container is destroyed — if you redeployed, recreate it
- `ip link show tun0` — verify the interface is UP

**OSPF over GRE not forming adjacency**
- Use `ip ospf network point-to-point` on the tun0 interface — without this, OSPF uses broadcast mode and tries to elect a DR/BDR on GRE (which fails)
- `show ip ospf interface tun0` — check the network type and timer values

**GRE vs IPsec**
- GRE: no encryption, supports multicast and routing protocols, simpler
- IPsec: encryption, harder to run routing protocols directly (needs GRE+IPsec)
- See the `gre-ipsec` lab for combining both
