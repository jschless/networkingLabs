# Topic Quiz — WireGuard

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `wireguard`.

## Section 1 — Mechanisms (4 points)

### A1 — Keys, endpoints, and allowed prefixes (4 points)

Explain the role of private/public keys, `Endpoint`, `AllowedIPs`, and a recent handshake.
Include the dual routing and source-validation behavior of `AllowedIPs`. (4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — Handshake succeeds, overlay address fails

```text
hub peer gw-a: latest handshake 12 seconds ago
hub peer gw-a AllowedIPs: 192.168.100.99/32
gw-a wg0 address: 192.168.100.10/24
hub route get 192.168.100.10: unreachable
```

Localize the fault, explain why crypto is healthy, and give the minimum repair plus two
verification checks. (6 pts)

## Section 3 — Application (5 points)

### C1 — Hub-and-spoke or mesh

Compare hub-and-spoke with a full mesh for ten sites. Address peer count, routes and
`AllowedIPs`, spoke-to-spoke path, failure concentration, and operational key lifecycle.
(5 pts)

## Section 4 — Design and troubleshooting (5 points)

### D1 — Rotate one peer safely

Design a key rotation for one spoke without exposing private keys or disrupting every
peer. Include identity mapping, overlap/cutover, handshake and traffic verification, and
rollback. (5 pts)

*Key: [`../answer-keys/quizzes/wireguard-key.md`](../answer-keys/quizzes/wireguard-key.md).*
