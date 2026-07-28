# Topic Quiz — Management-Plane Security

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `acl-basics`, `aaa-ops-troubleshooting`, `copp-basics`, and
`management-access-control`.

## Section 1 — Mechanisms (6 points)

### A1 — AAA outcomes (3 points)

Distinguish authentication, authorization, and accounting with one device-management
failure that can occur at each stage. Explain why a TACACS rejection is operationally
different from an unreachable TACACS server when local fallback is configured. (3 pts)

### A2 — ACLs and CoPP (3 points)

Contrast a management access ACL with control-plane policing. State which one answers
“who may connect” and which one limits CPU-bound traffic rates, and explain why neither
is a replacement for the other. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — Break-glass that never runs

After a WAN failure, centralized TACACS is unreachable.

```text
device1# show running-config section aaa
aaa authentication login default group tacacs+

device1# show users accounts
admin  role network-admin  local

device1 log:
TACACS: server 192.0.2.20 timed out
AAA: authentication failed; no remaining method
```

1. Identify the lockout cause. (2 pts)
2. Give the intended method-list behavior and explain when local fallback should occur.
   (2 pts)
3. Describe a safe change procedure that does not risk losing the only session. (2 pts)
4. Give two checks that distinguish server unreachable, shared-key mismatch, and an
   explicit credential rejection. (2 pts)

## Section 3 — Application (10 points)

### C1 — Layer a management-plane design

Design management access for branch routers that have an out-of-band interface and an
in-band backup path. Include:

- source/interface restrictions;
- encrypted management protocols;
- centralized AAA, authorization, accounting, and local break-glass;
- control-plane protection; and
- safe rollout and verification.

Explain how the design behaves when the production data plane, AAA server, or monitoring
system fails independently. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Protection that flaps the protocols

After a custom CoPP policy replaces the platform default, BGP and OSPF flap whenever an
ICMP flood targets the router. Transit forwarding remains fast.

Give two plausible classification or policing faults, a safe recovery method, and the
counters/control-plane checks that prove the repaired policy protects the CPU without
dropping legitimate routing traffic. (6 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/management-security-key.md`](../answer-keys/quizzes/management-security-key.md).*
