# Lab: VRRP (Virtual Router Redundancy Protocol)

## Purpose
Learn how VRRP provides first-hop redundancy: two routers share a single virtual IP address. Hosts use the VIP as their default gateway. If the master router fails, the backup takes over the VIP within seconds.

## Topology

```
             192.168.1.10/24
                  [host]
                    |
           192.168.1.0/24 LAN (br-lan)
            /               \
  192.168.1.1/24       192.168.1.2/24
       [r1] MASTER          [r2] BACKUP
  10.0.1.1/30            10.0.2.1/30
       |                        |
  10.0.1.2/30            10.0.2.2/30
       \                        /
              [server]
          lo: 10.99.0.1/32

VRRP VIP: 192.168.1.254 (shared between r1 and r2)
host default gateway: 192.168.1.254
```

## Deploy

```bash
sudo containerlab deploy -t topology.yml
```

## Pre-configured

- All IP addresses and interface configs
- Static routes: r1 and r2 each have a route to 10.99.0.1/32 via their server-facing link
- server has return routes toward 192.168.1.0/24 via both r1 and r2
- host uses 192.168.1.254 (the VRRP VIP) as default gateway

## Your Tasks

### Task 1 — Configure VRRP on r1 (master, priority 110)

```
vtysh -c "conf t" -c "interface eth1" \
      -c "vrrp 1 ip 192.168.1.254" \
      -c "vrrp 1 priority 110" \
      -c "vrrp 1 preempt"
```

Or enter vtysh interactively:
```
interface eth1
 vrrp 1 ip 192.168.1.254
 vrrp 1 priority 110
 vrrp 1 preempt
```

### Task 2 — Configure VRRP on r2 (backup, default priority 100)

```
interface eth1
 vrrp 1 ip 192.168.1.254
```

Priority defaults to 100, which is lower than r1's 110 — r1 wins the election.

### Task 3 — Verify

On r1:
```
show vrrp
show vrrp interface eth1
```

Expected output for r1:
```
Virtual Router ID  1
  State           Master
  Priority        110
  Virtual IP      192.168.1.254
  Virtual MAC     00:00:5e:00:01:01
```

On r2, State should show `Backup`.

### Task 4 — Test connectivity

From host, ping the server loopback through the VIP:
```
ping 10.99.0.1
```

### Task 5 — Failover test

Bring down r1's LAN interface to simulate a failure:
```bash
# On r1:
ip link set eth1 down
```

Immediately check r2:
```
show vrrp
```

r2 should now show `Master`. Within ~3 seconds (3 missed advertisements) r2 takes over.

Ping from host should resume within a few seconds.

### Task 6 — Preemption / recovery

Restore r1's interface:
```bash
# On r1:
ip link set eth1 up
```

Because `vrrp 1 preempt` is configured on r1, it will re-send advertisements with priority 110 and reclaim the Master role from r2 (which has priority 100).

Observe r1 transitioning: Backup -> Master, and r2 transitioning: Master -> Backup.

## Key Concepts

### VRRP Virtual MAC
The VIP always has the same MAC address regardless of which physical router is master:
```
00:00:5e:00:01:<VRID>
```
For VRID 1: `00:00:5e:00:01:01`

This is why ARP doesn't need to update on failover — the MAC is stable.

### Master Election
- Highest priority wins (range 1–254, default 100)
- Tiebreaker: highest IP address
- The IP address owner (router whose real IP equals the VIP) always wins (priority 255)

### Preemption
When `vrrp X preempt` is set, a router that recovers and has a higher priority than the current master will take over. FRR enables preempt by default.

### Advertisement Interval
The master sends VRRP advertisements every 1 second. If the backup misses 3 consecutive advertisements (3 seconds), it declares the master dead and transitions to Master state.

### Useful Commands

```
show vrrp                          # summary of all VRRP instances
show vrrp interface eth1           # detail for specific interface
show vrrp 1                        # detail for VRID 1
```

```
debug vrrp packets                 # log VRRP advertisement packets
debug vrrp events                  # log state transitions
```

## Failover Timing

| Event | Time |
|-------|------|
| Master fails | 0s |
| Backup detects (3 missed adv) | ~3s |
| Backup sends gratuitous ARP for VIP | ~3s |
| Hosts update ARP cache | ~3s |
| Traffic resumes | ~3–4s |

Preemption back to master is immediate (first advertisement with higher priority triggers it).

## Destroy

```bash
sudo containerlab destroy -t topology.yml
```
