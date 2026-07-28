# Topic Quiz — Remote Access and Zero Trust

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `opnsense-remote-access-concentrator` and
`zero-trust-secure-access`.

## Section 1 — Mechanisms (6 points)

### A1 — Tunnel identity versus application authorization (3 points)

Explain what a per-peer WireGuard handshake proves, what it does not authorize, and
where service-specific access should be enforced after tunnel establishment. (3 pts)

### A2 — Split tunnel and resource access (3 points)

Contrast split and full tunneling by route selection, DNS/Internet path, and inspection
coverage. Explain why zero-trust resource policy cannot rely only on the client being
inside a VPN subnet. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Connected contractor, denied application

```text
contractor latest WireGuard handshake: 18 seconds ago
route to 10.70.10.0/24: dev wg0
SSH to 10.70.10.20: success
HTTPS to 10.70.10.10: timeout
firewall log: deny contractor 10.250.0.20 -> 10.70.10.10 tcp/8443
```

1. Explain why this is not a tunnel or routing failure. (3 pts)
2. Identify the enforcing policy decision. (2 pts)
3. Give three checks that distinguish an intended least-privilege denial from a mistaken
   rule. (3 pts)

## Section 3 — Application (10 points)

### C1 — Protect finance by identity, device signal, and path

Design access to `/finance` so it requires the finance group plus a managed-client
certificate, while `/partner` has a distinct partner rule even if both use the same
origin. Include token validation, mTLS, PEP policy, origin-bypass prevention, and
positive/negative tests. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Revoke one principal without breaking everyone

Compare revoking one WireGuard peer with expiring or revoking one application identity
or device credential. Describe expected session timing, the evidence required to prove
selective loss of access, and why deleting a shared route or shutting the concentrator is
the wrong response. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/remote-access-key.md`](../answer-keys/quizzes/remote-access-key.md).*
