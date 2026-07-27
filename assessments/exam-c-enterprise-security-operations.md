# Exam C — Enterprise Design, Security & Operations

**Time:** 2 hours · **Total:** 100 points · **Closed book, no CLI**

Covers the Enterprise Design, Security, and Network Operations tracks — campus and DMZ
architecture, edge security and NAT, access-layer hardening, QoS, load balancing,
observability, and automation.

---

## Section 1 — Concepts & mechanisms (30 points)

Ten questions, 3 points each.

**C1.** DHCP snooping, Dynamic ARP Inspection, and IP Source Guard are configured together
in `enterprise-access-security` and are not three ways of doing the same thing. For each:
state the attack it stops, and state what it consumes or produces. Then explain why DAI and
IP Source Guard both **depend on** DHCP snooping, and what happens to a statically
addressed server on a snooping-enabled VLAN.

**C2.** Unicast RPF. Define strict and loose mode. Give the specific routing condition that
makes strict mode drop legitimate traffic, name a place in a real network where that
condition is normal rather than exceptional, and state which mode belongs on a
customer-facing edge port versus a transit link.

**C3.** In `qos-enterprise`, DSCP EF is 46 but the lab writes the ToS byte as `0xb8`.
(a) Show the arithmetic connecting the two and say what occupies the bits you did not use.
(b) A `tc` filter written to match ToS `0x2e` matches nothing. Explain why in one sentence.
(c) State the general principle about *where* in a network you mark and *where* you queue,
and give the reason they are different places.

**C4.** The QoS lab's HTB tree gives voice `rate 800kbit ceil 2mbit prio 1`, video `rate
600kbit ceil 2mbit prio 2` with GRED, and data `rate 600kbit ceil 2mbit prio 3` with SFQ,
on a 2 Mbit/s link. (a) What does `ceil` permit that `rate` does not, and under what
condition? (b) Why is SFQ on the data class and GRED on the video class, rather than the
other way round?

**C5.** Load balancing: state one thing an **L7** load balancer can do that an **L4** one
structurally cannot, and one cost you pay for it. Then explain what `X-Forwarded-For`
exists to solve, and why it is untrustworthy unless a specific condition holds.

**C6.** 802.1X. Name the three roles and which protocol runs between each pair. Then:
(a) what is MAB, and what is the security trade-off in enabling it; (b) why is EAP-TLS
stronger than PEAP/MSCHAPv2, in terms of what each end proves to the other; (c) what does
"dynamic VLAN assignment" mean, and which entity decides.

**C7.** SNMP, syslog, SPAN, and NetFlow are the four mechanisms in `network-assurance`. For
each, state in one line the question it answers that the other three cannot, and rank all
four by the load they put on the device and the network.

**C8.** Automation. (a) Define **idempotence** and explain why it matters more for
configuration than for a one-off script. (b) `automation-fundamentals` insists you
**verify from the other router**. What class of bug does verifying locally miss? (c) Name
one structural difference between eAPI (JSON-RPC over HTTP) and NETCONF that affects how
you write change logic, not merely how you encode it.

**C9.** NAT. (a) Explain the ordering relationship between destination NAT and the firewall
forward/filter decision on a Linux/nftables edge, and what the filter rule must match as a
result. (b) Define connection tracking's role in allowing return traffic. (c) Explain
hairpin NAT and the symptom of not configuring it.

**C10.** VRRP as this repo teaches it versus HSRP/GLBP as the CCNP exams teach it. Name the
concept that is identical, two things that genuinely differ, and state the one operational
behaviour of VRRP that most often surprises someone who learned HSRP first.

---

## Section 2 — Evidence reading (20 points)

### C-E1 (7 points)

An edge router publishes a DMZ web service. External clients get connection timeouts. The
ruleset and its counters:

```text
table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "eth0" ip daddr 203.0.113.10 tcp dport 443 counter packets 812 bytes 48720 dnat to 172.16.0.11:8443
    }
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        ip saddr 172.16.0.0/24 oifname "eth0" counter packets 0 bytes 0 masquerade
    }
}
table ip filter {
    chain forward {
        type filter hook forward priority filter; policy drop;
        ct state established,related counter packets 0 bytes 0 accept
        iifname "eth0" oifname "eth1" ip daddr 203.0.113.10 tcp dport 443 counter packets 0 bytes 0 accept
    }
}
```

(a) The DNAT rule has counted 812 packets and the accept rule has counted zero. Explain
exactly why, in terms of the order the hooks run. (3 pts)
(b) Write the corrected `forward` rule. (2 pts)
(c) After your fix, will the `established,related` counter start incrementing, and does the
`masquerade` rule have any part in this flow? Justify both. (2 pts)

### C-E2 (7 points)

From the `qos-enterprise` router, during a test where all three clients are transmitting
and the 2 Mbit/s WAN is saturated:

```text
router# tc -s class show dev eth4
class htb 1:10 root leaf 10: prio 1 rate 800Kbit ceil 2Mbit
 Sent 0 bytes 0 pkt (dropped 0, overlimits 0 requeues 0)
 backlog 0b 0p requeues 0

class htb 1:20 root leaf 20: prio 2 rate 600Kbit ceil 2Mbit
 Sent 14882320 bytes 10122 pkt (dropped 431, overlimits 0 requeues 0)
 backlog 24960b 17p requeues 0

class htb 1:30 root leaf 30: prio 3 rate 600Kbit ceil 2Mbit
 Sent 22140880 bytes 15061 pkt (dropped 1904, overlimits 0 requeues 0)
 backlog 62400b 41p requeues 0
```

The voice client is definitely sending — a capture on its access interface shows a steady
500 kbit/s UDP stream.

(a) State what has gone wrong, precisely. (2 pts)
(b) Where is the voice traffic actually going, and what evidence in this output supports
that? (2 pts)
(c) Name the two most likely configuration causes and the single command you would run to
tell them apart. (3 pts)

### C-E3 (6 points)

In `load-balancer-basics`, NAT-mode balancing has been configured on `edge`. Requests from
`client` (203.0.113.2) to the VIP hang. A capture taken on **edge2** — the second router
that is supposed to carry no traffic — shows:

```text
15:22:41.118 IP 172.16.0.11.8080 > 203.0.113.2.51422: Flags [S.], seq 2043221, ack 1, win 64240
15:22:42.121 IP 172.16.0.11.8080 > 203.0.113.2.51422: Flags [S.], seq 2043221, ack 1, win 64240
15:22:44.129 IP 172.16.0.11.8080 > 203.0.113.2.51422: Flags [S.], seq 2043221, ack 1, win 64240
```

Nothing at all appears on edge for the return direction.

(a) Name the failure and describe the full path each direction of the flow is taking.
(2 pts)
(b) The SYN-ACKs are being retransmitted at 1 s, 2 s, 4 s. What does that interval pattern
tell you about which end is confused? (1 pt)
(c) Why does this break even though `edge2` has a perfectly good route back to
203.0.113.0/29 and is willing to forward? Name the mechanism. (2 pts)
(d) Give the fix at the routing layer and the fix at the design layer — they are different
answers. (1 pt)

---

## Section 3 — Implementation on paper (25 points)

### C1 (10 points) — nftables

Write a complete `nftables` policy for a DMZ edge router with `eth0` outside
(`203.0.113.1/29`), `eth1` to the DMZ (`172.16.0.1/24`), and `eth2` to the internal LAN
(`10.1.0.1/24`). Requirements:

- publish `203.0.113.10:443` to the DMZ web server `172.16.0.11:8443`
- DMZ hosts may reach the internet, source-NATted to the outside address
- internal LAN may reach the internet and the DMZ
- **the DMZ may never initiate a connection to the internal LAN** — this is the point of a
  screened subnet
- return traffic for all permitted flows must work
- default deny

Include the tables, chains with their hooks and priorities, and the rules. State the base
policy on each chain.

### C2 (8 points) — Arista EOS

Write the access-layer hardening for a cEOS access switch. `Ethernet1` faces a user PC on
VLAN 10; `Ethernet48` is the uplink trunk to the distribution switch. Configure:

- DHCP snooping for VLAN 10, with the correct trust setting on each of the two ports
- Dynamic ARP Inspection for VLAN 10
- port security limiting Ethernet1 to two MAC addresses
- the two STP protections appropriate to each of the two ports — they are not the same one

For each command, be explicit about **which interface** it goes on. Then state in one line
what would break if you set the trust boundary the other way round.

### C3 (7 points) — Automation logic

Write pseudocode (or Python; syntax is not graded) for an eAPI script that ensures **r1
advertises its loopback `10.0.0.1/32` to its eBGP peer r2**, following the
read → change → verify loop from `automation-fundamentals`. It must:

- read current state as **structured data**, not screen-scraped text
- be **idempotent** — make no change and report no change when already correct
- verify the result, and verify it in a way that would catch a change that committed
  locally but had no effect on the peer relationship
- report a drift result the caller can act on

Annotate which line is the idempotence check and which is the verification, and state what
your script does if the verification fails after a successful commit.

---

## Section 4 — Design & trade-offs (15 points)

### D1 (8 points)

This repo builds three campus designs: **collapsed core**
(`enterprise-collapsed-core`), **three-tier**  (`enterprise-campus`), and **routed access**
(`enterprise-routed-access`).

(a) For each, state where the L2/L3 boundary sits and what runs the first-hop gateway
function. (3 pts)
(b) Routed access removes spanning tree from the access layer entirely. State what you gain
and the two concrete things you give up. (3 pts)
(c) You are designing for a 900-user site in three buildings, with a requirement that a
single VLAN must span two buildings for a legacy application. Which design do you choose,
and what does the legacy requirement cost you? (2 pts)

### D2 (7 points)

You must instrument a network so that an on-call engineer can answer these three questions
at 3 a.m.:

1. "Was there a link flap on the core between 02:40 and 02:50?"
2. "Which host consumed the WAN circuit at 02:45?"
3. "What exactly did the malformed request to the DMZ web server contain?"

(a) Map each question to the mechanism from `network-assurance` that answers it, and say
why the other three cannot. (3 pts)
(b) One of these mechanisms cannot be left running continuously across the whole network.
Name it, explain the constraint, and describe how you would deploy it so it is available
when needed. (2 pts)
(c) Give one failure mode of relying on the mechanism that answers question 1, and the
design change that mitigates it. (2 pts)

---

## Section 5 — Troubleshooting narrative (10 points)

### C-E4

**Ticket:** *"Since the new inspection appliance went in last night, users on the corporate
LAN can reach the cloud-hosted application, but sessions drop after about 60 seconds of
inactivity and new sessions sometimes fail entirely. Nothing changed on the cloud side."*

Environment is `cloud-hybrid-networking`: an on-premises edge with eBGP to a cloud transit
domain, an inspection path, private DNS, and a known history of asymmetric-return faults.

Structure your answer:

1. **Read the symptom.** "Drops after 60 seconds of inactivity" and "new sessions sometimes
   fail" are two different faults or one — argue your position and say what each half
   points at. (3 pts)
2. **Three pieces of evidence** you would gather, from three different layers, with what
   each would show under your leading hypothesis. (3 pts)
3. **Why "nothing changed on the cloud side" is consistent with the cloud side being where
   the packets die.** (1 pt)
4. **The most likely cause**, stated as a specific mechanism, not a component name. (2 pts)
5. **Fix and verification**, where the verification must distinguish your fix from a
   coincidental recovery. (1 pt)

---

*End of Exam C. Key: [`answer-keys/exam-c-key.md`](answer-keys/exam-c-key.md).*
