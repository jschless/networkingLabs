# Topic Quiz — NAT & Stateful Firewalls

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `enterprise-edge-nat-firewall`, `enterprise-dmz`, and
`opnsense-ngfw-basics`.

## Section 1 — Mechanisms (4 points)

### A1 — Translation is not permission

Contrast DNAT for publishing, SNAT/PAT for outbound clients, and a stateful firewall
decision. Explain why a port forward still needs an explicit WAN policy. (4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — The rule matches the wrong destination

```text
prerouting: tcp dport 443 dnat to 172.16.10.20
forward: ip daddr 203.0.113.10 tcp dport 443 accept
forward policy drop
```

Packets reach prerouting but never reach the server.

1. Explain the ordering error and the destination the forward rule must match. (3 pts)
2. State the corrected policy and two verification points. (3 pts)

## Section 3 — Application (5 points)

### C1 — Minimal DMZ matrix

Write a policy matrix for internet, corporate, guest, DMZ web, and database zones that
permits public HTTPS, corporate management, DMZ-web-to-database TCP/3306, and outbound
internet access while preventing guest or general DMZ pivoting. Include required NAT.
(5 pts)

## Section 4 — Troubleshooting (5 points)

### D1 — Public name fails only inside

External users reach the published DMZ service, but corporate users resolving the same
public address fail. Diagnose the likely mechanism, describe a hairpin-NAT repair, and
give evidence distinguishing it from DNS or server failure. (5 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/nat-firewall-key.md`](../answer-keys/quizzes/nat-firewall-key.md).*
