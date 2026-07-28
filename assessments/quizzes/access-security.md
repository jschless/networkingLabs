# Topic Quiz — Enterprise Access Security

**Time:** 35 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `enterprise-access-security`, `dot1x-nac`, `dot1x-ceos-practice`,
and `urpf-antispoofing`.

## Section 1 — Mechanisms (6 points)

### A1 — One binding, three controls (3 points)

State what DHCP snooping produces and how Dynamic ARP Inspection and IP Source Guard use
that result to stop different attacks. Include the statically addressed host problem.
(3 pts)

### A2 — Admission and source validation (3 points)

Name the 802.1X roles and protocols, explain MAB's trade-off, and contrast strict with
loose uRPF for a multihomed edge. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Authentication succeeded, authorization did not

```text
RADIUS: Access-Accept user=alice
Tunnel-Type=VLAN
Tunnel-Private-Group-ID=20

switch# show dot1x interface Ethernet5
Status: Authorized
Operational VLAN: 99
```

Alice authenticates with EAP-TLS but reaches only quarantine services.

1. Separate the successful authentication evidence from the failed authorization action.
   (3 pts)
2. Give two switch-side causes and the evidence distinguishing them. (2 pts)
3. State three checks proving identity, VLAN assignment, and resulting access policy.
   (3 pts)

## Section 3 — Application (10 points)

### C1 — Place the controls

For a user VLAN with DHCP server traffic arriving on uplink Ethernet48 and clients on
Ethernet1–24, specify where trust belongs and where DHCP snooping, DAI, IP Source Guard,
802.1X/MAB, and BPDU Guard apply. Explain two outages caused by trusting the wrong port.
(10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Strict uRPF drops a legitimate customer

A customer's packets enter link A, but policy makes the best return route use link B.
Explain the strict-mode drop, select a safer validation design, and state what protection
is lost plus how you would verify it. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/access-security-key.md`](../answer-keys/quizzes/access-security-key.md).*
