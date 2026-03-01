# debug-gre-basics — GRE tunnel unreachable despite interface showing up

## Scenario

A colleague configured GRE tunnels between two gateway routers (gw-a and gw-b) to connect two remote office LANs. After deployment, host-to-host pings fail completely. The tunnel interfaces exist on both gateways and show as UP/UP, but no traffic crosses. WAN reachability between the gateways is confirmed working.

## Topology

```
[host-a]──────[gw-a]──────[internet]──────[gw-b]──────[host-b]
192.168.1.10   LAN: 192.168.1.1           LAN: 192.168.2.1   192.168.2.10
               WAN: 203.0.113.1           WAN: 203.0.113.6
               tun0: 172.16.0.1           tun0: 172.16.0.2
```

## IP / Node Reference

| Node     | Interface  | IP Address        | Role              |
|----------|-----------|-------------------|-------------------|
| host-a   | eth1      | 192.168.1.10/24   | LAN A host        |
| gw-a     | eth1      | 192.168.1.1/24    | LAN A gateway     |
| gw-a     | eth2      | 203.0.113.1/30    | WAN uplink        |
| gw-a     | tun0      | 172.16.0.1/30     | GRE tunnel        |
| internet | eth1      | 203.0.113.2/30    | WAN transit       |
| internet | eth2      | 203.0.113.5/30    | WAN transit       |
| gw-b     | eth1      | 203.0.113.6/30    | WAN uplink        |
| gw-b     | eth2      | 192.168.2.1/24    | LAN B gateway     |
| gw-b     | tun0      | 172.16.0.2/30     | GRE tunnel        |
| host-b   | eth1      | 192.168.2.10/24   | LAN B host        |

## Expected Behavior

- `ping 203.0.113.6` from gw-a succeeds (WAN reachability)
- `ping 172.16.0.2` from gw-a succeeds (tunnel works)
- `ping 192.168.2.10` from host-a succeeds (end-to-end)
- Symmetric: gw-b and host-b can reach gw-a and host-a

## Deploy & Access

```bash
sudo containerlab deploy -t topology.yml

# Access gateways (tunnel config is in bash, not vtysh)
docker exec -it clab-debug-gre-basics-gw-a bash
docker exec -it clab-debug-gre-basics-gw-b bash

# Access hosts
docker exec -it clab-debug-gre-basics-host-a bash
docker exec -it clab-debug-gre-basics-host-b bash
```

## Observed Symptoms

```bash
# On host-a:
ping 192.168.2.10
# PING 192.168.2.10: 100% packet loss

# On gw-a — WAN reachability is fine:
ping 203.0.113.6
# 64 bytes from 203.0.113.6: icmp_seq=1 ttl=64 time=0.3 ms

# On gw-a — tunnel fails:
ping 172.16.0.2
# PING 172.16.0.2: 100% packet loss

# On gw-b — WAN reachability is fine:
ping 203.0.113.1
# 64 bytes from 203.0.113.1: icmp_seq=1 ttl=64 time=0.2 ms

# On gw-b — tunnel fails:
ping 172.16.0.1
# PING 172.16.0.1: 100% packet loss
```

## Your Task

Identify the misconfiguration using show commands. Do not look at the `setup.sh` files yet — diagnose from symptoms first.

The tunnel interfaces exist on both gateways. WAN routing is correct. Why does tunnel traffic fail in both directions?

## Useful Show Commands

```bash
# Run inside container bash (docker exec -it clab-debug-gre-basics-gw-b bash)

# Check tunnel configuration on each gateway:
ip tunnel show
ip tunnel show tun0
ip addr show tun0

# Test connectivity at each layer:
ping 203.0.113.1       # WAN reachability from gw-b
ping 172.16.0.1        # Tunnel reachability from gw-b

# Trace the path:
traceroute 172.16.0.1

# Check routing:
ip route show
```

## Hints

<details><summary>Hint 1 — Where to start</summary>

WAN reachability works fine — the physical path is correct. The tunnels are up but traffic doesn't flow. Start by comparing the tunnel configuration on **both** gateways. Use `ip tunnel show tun0` on gw-a and gw-b, and compare the output side by side.

</details>

<details><summary>Hint 2 — Narrowing it down</summary>

Look at the `remote` field in `ip tunnel show tun0` on each gateway:
- gw-a should show `remote 203.0.113.6` (gw-b's WAN IP)
- gw-b should show `remote 203.0.113.1` (gw-a's WAN IP)

Do the `remote` addresses match what you'd expect? Cross-reference with `ip addr show eth1` on the gateway you're checking against.

</details>

<details><summary>Hint 3 — The specific problem</summary>

Run `ip tunnel show tun0` on gw-b. The `remote` field shows `192.168.1.1` — that's gw-a's **LAN** IP (192.168.1.1/24), not its **WAN** IP (203.0.113.1/30). GRE-encapsulated packets from gw-b are sent toward 192.168.1.1, which is unreachable from the WAN. Simultaneously, gw-b rejects incoming GRE packets from 203.0.113.1 because they don't match the expected remote (192.168.1.1).

</details>

## Solution

<details><summary>Fix (don't peek!)</summary>

On **gw-b** (inside container bash):

```bash
ip tunnel del tun0
ip tunnel add tun0 mode gre local 203.0.113.6 remote 203.0.113.1 ttl 255
ip link set tun0 up
ip addr add 172.16.0.2/30 dev tun0
```

The correct remote for gw-b's tunnel is gw-a's **WAN** IP: `203.0.113.1`.

</details>

## Verification

After applying the fix on gw-b:

```bash
# Confirm tunnel config:
ip tunnel show tun0
# tun0: gre/ip  remote 203.0.113.1  local 203.0.113.6  ttl 255

# Test tunnel:
ping 172.16.0.1
# 64 bytes from 172.16.0.1: icmp_seq=1 ttl=64 time=0.5 ms

# End-to-end test from host-b:
ping 192.168.1.10
# 64 bytes from 192.168.1.10: icmp_seq=1 ttl=64 time=0.8 ms
```
