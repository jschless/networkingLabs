# SD-WAN Concepts — Reference Lab

SD-WAN marketing says "application-aware routing over any transport with
automatic failover." Strip away the controllers and what remains is a small
set of mechanisms: a tunnel per transport, routes distributed over the
overlay, a classifier steering applications onto paths, and probes deciding
when a path is dead. This lab builds **all of them by hand** on two branch
routers — and the point of the lab is the mapping: once you've typed each
mechanism yourself, every box in a vManage diagram is something you've
already built, just automated and scaled.

This is a **reference lab**: everything is pre-configured and working at
deploy. Your job is the demos — **predict, trigger, observe** — and the
challenge questions.

## Topology

```
                    ┌─────────────┐
            ┌── eth2┤  mpls-core  ├eth2 ──┐         "MPLS" transport
            │       │ 172.16.x.x  │       │          (premium, SLA)
  h1        │       └─────────────┘       │        h2
   │        │                             │         │
10.1.0.10   │                             │     10.2.0.10
   │     branch1                       branch2       │
   └─eth1───┤                             ├───eth1───┘
 LAN1       │       ┌─────────────┐       │       LAN2
10.1.0.0/24 └── eth3┤  inet-core  ├eth3 ──┘    10.2.0.0/24
                    │198.51.100.x │                "internet" transport
                    └─────────────┘                 (cheap, best-effort)

  Overlay:  tun-mpls 10.255.1.0/30   (GRE over the MPLS transport)
            tun-inet 10.255.2.0/30   (GRE over the internet)
```

| Segment | Subnet | Hosts |
|---------|--------|-------|
| LAN1 | 10.1.0.0/24 | branch1=.1, h1=.10 |
| LAN2 | 10.2.0.0/24 | branch2=.1, h2=.10 |
| MPLS transport (b1) | 172.16.1.0/30 | branch1=.1, mpls-core=.2 |
| MPLS transport (b2) | 172.16.2.0/30 | branch2=.1, mpls-core=.2 |
| Internet transport (b1) | 198.51.100.0/30 | branch1=.1, inet-core=.2 |
| Internet transport (b2) | 198.51.100.4/30 | branch2=.5, inet-core=.6 |
| Overlay tun-mpls | 10.255.1.0/30 | branch1=.1, branch2=.2 |
| Overlay tun-inet | 10.255.2.0/30 | branch1=.1, branch2=.2 |

The policy, pre-built on both branches: **voice (DSCP EF) rides the MPLS
tunnel; everything else rides the internet tunnel.** A 1-second ping probe
(`pathmon`, running on each branch) watches the MPLS tunnel and moves voice
to the internet tunnel after 3 lost probes, back after 3 good ones.

## The mapping (read this twice)

Every mechanism in this lab is one box of the Cisco Catalyst SD-WAN (former
Viptela) architecture, built manually:

| You did it as… | SD-WAN does it as… |
|----------------|--------------------|
| Two WAN interfaces with distinct transports | **TLOCs** with **colors** (`mpls`, `biz-internet`) |
| `ip tunnel add ... mode gre` per transport, full mesh of 2 | IPsec tunnels auto-negotiated between every TLOC pair (and it's encrypted — GRE here is cleartext; see the `ipsec-basics`/`gre-ipsec` labs) |
| `ip route add 10.2.0.0/24 via <tunnel>` typed on each box | **OMP**: vSmart reflects every site's routes + TLOCs to every other site — the "BGP route reflector of the overlay" |
| nftables `ip dscp ef meta mark set 1` + `ip rule fwmark 1 table 100` | **Centralized data policy / app-aware routing**: vSmart pushes match-app → prefer-color policy; vEdge classifies with DPI, not just DSCP |
| `pathmon.sh` pinging the tunnel peer 1/s, threshold 3 | **BFD probes** on every tunnel, measuring **loss/latency/jitter**, feeding app-route **SLA classes** |
| `ip route replace ... table 100` on failure | SLA-class violation → traffic moves to the next color meeting the SLA |
| You, typing on two routers (and re-pinning a flushed static route) | **vManage** templates rendering config for hundreds of sites; ZTP onboarding; a routing protocol keeping the underlay alive |

Two routers and ~40 lines of setup were enough by hand. The product exists
because at 200 sites × 3 transports it is 600 TLOCs, ~180,000 potential
tunnels, and a policy change is a Tuesday — the *mechanisms* don't change,
the **control plane** does.

## Deploy

```bash
# one-time image build (FRR base + iproute2/nftables/iputils/tcpdump)
docker build -t sdwan-lab:local labs/sdwan-concepts/

./scripts/lab.sh deploy sdwan-concepts
./scripts/lab.sh check sdwan-concepts     # all 14 should pass once converged
```

No licensed images required.

## Demo 1 — Read the machine

**Objective:** Before triggering anything, account for every piece on
branch1.

```bash
docker exec clab-sdwan-concepts-branch1 ip -br addr      # 2 WAN + 2 tunnels
docker exec clab-sdwan-concepts-branch1 ip route          # overlay default via tun-inet
docker exec clab-sdwan-concepts-branch1 ip route show table 100   # voice table
docker exec clab-sdwan-concepts-branch1 ip rule           # fwmark 1 -> table 100
docker exec clab-sdwan-concepts-branch1 nft list ruleset  # EF -> mark 1
docker exec clab-sdwan-concepts-branch1 tail /var/log/pathmon.log
```

**Predict first:** `ip route get 10.2.0.10 from 10.1.0.10 iif eth1` — which
tunnel? Same query with `mark 1` appended — which tunnel? Answer both from
the rules you just read, then run them.

<details>
<summary>Check your work</summary>

Unmarked: `via 10.255.2.2 dev tun-inet` (main table — the cheap path is the
default). With `mark 1`: `via 10.255.1.2 dev tun-mpls table 100`. The kernel
consulted `ip rule` first, matched `fwmark 0x1 lookup 100`, and used the
voice table. That two-step — classify, then route by class — *is*
"application-aware routing"; everything else is automation around it.

</details>

## Demo 2 — Watch the split happen

**Objective:** Prove with packets that DSCP decides the transport.

Start captures on both cores, then send both classes from h1:

```bash
# terminal 1 and 2 (or use ./scripts/lab.sh cmd):
docker exec clab-sdwan-concepts-mpls-core tcpdump -v -ni eth1 proto gre
docker exec clab-sdwan-concepts-inet-core tcpdump -v -ni eth1 proto gre

# terminal 3:
docker exec clab-sdwan-concepts-h1 ping -c3 10.2.0.10            # best-effort
docker exec clab-sdwan-concepts-h1 ping -Q 184 -c3 10.2.0.10     # voice: -Q 184 = tos 0xb8 = DSCP EF
```

**Predict first:** which capture shows which ping — and on the MPLS capture,
what `tos` value will the **outer** (GRE) IP header carry?

<details>
<summary>Check your work</summary>

The plain pings appear only on **inet-core**, the `-Q 184` pings only on
**mpls-core** — each as `IP ... > ...: GREv0 ... IP 10.1.0.10 > 10.2.0.10:
ICMP`. You'll also see a steady 1/s ICMP between 10.255.1.1 and 10.255.1.2
on mpls-core: that's pathmon, the probe traffic that real SD-WAN would call
BFD.

The outer-header prediction is the trap: the **inner** header carries
`tos 0xb8`, but the outer GRE header is `tos 0x0` — Linux GRE doesn't copy
DSCP to the outer header by default. The provider's QoS only ever sees the
outer header, so this voice traffic would ride the MPLS network in the
best-effort class. Real SD-WAN (and `ip tunnel`'s `tos inherit` option)
copies the inner DSCP out precisely because of this.

</details>

## Demo 3 — Blackout: kill the premium path

**Objective:** Watch hand-rolled "BFD" do its one job.

**Predict first:** after the MPLS link drops — (a) how many seconds until
voice fails over (derive it from pathmon's probe interval and threshold),
(b) does *best-effort* traffic notice anything, and (c) what happens at
branch2, which you didn't touch?

```bash
# keep a voice ping running in one terminal:
docker exec clab-sdwan-concepts-h1 ping -Q 184 10.2.0.10

# in another, drop branch1's MPLS link:
docker exec clab-sdwan-concepts-branch1 ip link set eth2 down
docker exec clab-sdwan-concepts-branch1 tail -f /var/log/pathmon.log

# then bring it back and keep watching the log:
docker exec clab-sdwan-concepts-branch1 ip link set eth2 up
```

<details>
<summary>Check your work</summary>

(a) ~3–4 seconds: 3 probes × 1s, plus up to a second of phase. The running
voice ping loses a few packets, then continues — check
`ip route show table 100`: voice now points at `tun-inet`. (b) Best-effort
never flinches; it was already on the internet path. (c) branch2's pathmon
fails over **independently** at nearly the same moment — its probes died
too. Nobody coordinated that; each edge made its own decision from its own
probes, which is exactly how SD-WAN forwarding-plane failover works (the
controllers are *not* in the loop — a vSmart outage doesn't stop failover).

After `ip link set eth2 up`, the log shows `RESTORE` within a few seconds
and table 100 points back at tun-mpls. One subtlety worth reading in
`configs/branch1/pathmon.sh`: when the link flapped, the kernel flushed the
static underlay route, so the monitor re-pins it every cycle — a real
deployment runs a routing protocol on the transport instead of static
routes, and this is why.

</details>

## Demo 4 — Brownout: the path your monitor can't see failing

**Objective:** Degrade the MPLS path *without* killing it, and catch the
gap between blackout detection and SLA enforcement.

**Predict first:** with 150 ms of added latency on the MPLS core — will
pathmon fail voice over to the internet path? Commit, then:

```bash
docker exec clab-sdwan-concepts-mpls-core tc qdisc add dev eth1 root netem delay 150ms

docker exec clab-sdwan-concepts-h1 ping -Q 184 -c3 10.2.0.10    # voice
docker exec clab-sdwan-concepts-h1 ping -c3 10.2.0.10           # best-effort
docker exec clab-sdwan-concepts-branch1 tail /var/log/pathmon.log
docker exec clab-sdwan-concepts-branch1 ip route show table 100

# clean up:
docker exec clab-sdwan-concepts-mpls-core tc qdisc del dev eth1 root
```

<details>
<summary>Check your work</summary>

No failover. Voice RTT is now ~150 ms (unusable for a phone call — the ITU
budget is ~150 ms *one-way*, and that's the whole budget, not one link)
while best-effort enjoys sub-millisecond RTT on the "cheap" path. Pathmon
stays silent because its probes still come back inside the 1-second
timeout: **the premium path is now the worst path, and the monitor calls it
UP.**

This is the single best argument for real app-route SLA machinery: Catalyst
SD-WAN's BFD probes timestamp every packet, compute loss/latency/jitter per
tunnel over a sliding window, and compare them to per-app SLA classes
(voice: loss ≤ 1%, latency ≤ 150 ms, jitter ≤ 30 ms). Try `netem loss 40%`
too: pathmon (needing 3 *consecutive* losses) mostly won't trigger on
random 40% loss — another measurement the ping-counter model gets wrong.

</details>

## Verification

```bash
./scripts/lab.sh check sdwan-concepts
```

14 checks: containers, both overlay tunnels, end-to-end for both traffic
classes, policy path selection in both tables, and both path monitors
running. (Run it in the lab's normal state — mid-demo, with links down or
netem applied, the path-selection checks will rightly complain.)

## Challenge questions

No answers provided — argue them from the lab.

1. This lab needed exactly one tunnel per transport pair because there are
   two sites. Derive the tunnel count for 100 sites × 2 transports in a
   full mesh, then explain what OMP + centralized policy let an operator do
   about it (hub-and-spoke, regional mesh) *without* touching branch
   configs the way you'd have to here.
2. The Demo 2 outer-header finding: list the two places QoS must be honored
   for voice to actually survive congestion (overlay marking, underlay
   scheduling), and who controls each in an MPLS-VPN vs an internet
   transport.
3. Design the probe that catches Demo 4: probe rate, what you measure,
   window size, and the flap-damping problem you've just created when the
   path hovers around the threshold. Where did pathmon's `THRESHOLD=3`
   land on that trade-off for blackouts?
4. pathmon re-pins a static underlay route every second — a hack standing
   in for a routing protocol. What *specifically* breaks if you instead run
   the overlay's routing protocol (say BGP) across the tunnels and let it
   handle transport failure too — why do SD-WAN designs keep underlay
   reachability, overlay routing, and path health as three separate
   mechanisms?
5. Both branches failed over independently in Demo 3. Construct a failure
   where independent per-edge decisions produce an *asymmetric* path (voice
   A→B on MPLS, B→A on internet). Does anything in this lab prevent it?
   Does it matter — and what would, say, a stateful firewall in one of the
   transports do to your answer?

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `check.sh` voice-path check fails | A demo left voice failed over, or pathmon died | `tail /var/log/pathmon.log` on both branches; bring eth2 up; `pgrep -f pathmon` |
| Tunnel pings fail right after deploy | Setup scripts still running / first probe cycle | wait ~5s, re-run `check.sh` |
| `ping -Q 184` takes the internet path | nft classifier or ip rule missing on a branch | `nft list ruleset`, `ip rule` — both branches need them (policy is per-direction) |
| Voice never restores after a link-flap demo | Underlay route flushed and pathmon not running to re-pin it | restart it: `nohup sh /pathmon.sh > /var/log/pathmon.log 2>&1 &` |
| netem command: `RTNETLINK answers: File exists` | A previous netem qdisc still installed | `tc qdisc del dev eth1 root` on the core, then re-add |
| Everything broken after host sleep/restart | containerlab veths don't survive that | redeploy: `./scripts/lab.sh deploy sdwan-concepts` |

## Extensions

- **Encrypt a color**: rebuild tun-inet as WireGuard or GRE-over-IPsec
  (see `wireguard`, `gre-ipsec`) — internet colors are never cleartext in
  real deployments.
- **Honest outer-header QoS**: recreate the tunnels with `tos inherit`
  (`ip tunnel add ... tos inherit`) and re-run Demo 2 — then decide who
  should trust that marking on the internet transport.
- **Real SLA probes**: replace pathmon's ping counter with a loss-percentage
  window (e.g. 10 probes, fail at ≥30% loss) and re-run Demo 4's
  `netem loss 40%` — then induce flapping and discover why hold-down timers
  exist.
- **OMP by hand**: run BGP between the branches across both tunnels (the
  FRR daemons are in the image) and let it replace the static overlay
  routes — then compare convergence against pathmon's.
