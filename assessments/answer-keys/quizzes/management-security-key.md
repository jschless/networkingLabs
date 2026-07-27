# Answer Key — Management-Plane Security Topic Quiz

**Total:** 30 points

## A1 — AAA outcomes (3 points)

- Authentication proves identity; it can fail because credentials or the identity
  service are unavailable/invalid. Authorization decides permitted roles or commands, so
  an authenticated user can still be denied configuration access. Accounting records
  activity; commands can work while the audit record fails or has unusable timestamps.
  (2)
- An unreachable/erroring TACACS server normally advances to the next configured method,
  such as `local`. An explicit TACACS reject is an authoritative denial and should not
  automatically fall through to a local account with the same attempted identity. (1)

## A2 — ACLs and CoPP (3 points)

- A source/interface management ACL decides which origins and services may connect. (1)
- CoPP classifies and rate-limits traffic punted to the router CPU, including permitted
  management and routing-control traffic; it does not govern ordinary transit traffic.
  (1)
- ACLs without policing permit an allowed source to overwhelm the CPU, while CoPP without
  access restrictions still exposes services to unauthorized attempts. Both controls
  are required. (1)

## B1 — Break-glass that never runs (8 points)

1. The default method list contains only `group tacacs+`; although a local admin exists,
   `local` is not a remaining authentication method after the TACACS timeout. (2)
2. Configure `aaa authentication login default group tacacs+ local`. Local fallback runs
   when the group is unavailable/errors, while a valid server's explicit reject remains
   a reject rather than bypassing central policy. (2)
3. Keep the current session open, obtain console/OOB access or a timed rollback, add and
   validate the local method/account from a second session, and only then close the
   original session. (2)
4. Award 1 point each for two useful distinctions: test IP/TCP reachability to the server;
   compare device and TACACS logs for timeout versus response; inspect server logs for
   bad shared-key packet validation versus explicit user reject; or test the known local
   account only after deliberately isolating the server from a safe console. (2)

## C1 — Layer a management-plane design (10 points)

- Prefer isolated OOB management with explicit in-band backup; restrict both by ingress
  interface and approved administrative source prefixes. (2)
- Permit only encrypted, needed services such as SSH/HTTPS with strong host identity;
  deny legacy cleartext protocols and verify rule counters. (1)
- Use centralized AAA with role/command authorization and accounting, plus a protected,
  tested local break-glass account and reliable time synchronization. (2)
- Apply CoPP classes/rates for routing, management, infrastructure control, and default
  traffic without replacing a safe platform policy blindly. (2)
- Roll out from console/OOB with backups, a second validation session, negative source
  tests, protocol adjacency checks, and a rollback timer or plan. (2)
- Data-plane failure should leave OOB usable; AAA failure should invoke controlled local
  fallback; monitoring failure must not itself remove management access, though it should
  alert through an independent path. (1)

## D1 — Protection that flaps the protocols (6 points)

- Two plausible faults, 1 point each: BGP/OSPF ACLs miss a direction/protocol and fall
  into a low-rate default class; class ordering sends routing packets to the ICMP/default
  class; a routing policer is below normal burst/keepalive demand; or the custom policy
  omitted safe default-system handling. (2)
- Recover through console/OOB or the surviving session by removing the custom service
  policy, not by disabling the routing protocols. Repair and validate the policy off-box
  or with a timed rollback before reapplying it. (2)
- Check per-class packet/drop/policer counters during controlled ICMP and routing traffic,
  CPU/load, BGP/OSPF stability, and management reachability. The repaired policy should
  drop excess attack traffic while legitimate routing-class counters rise without drops.
  (2)

## Remediation

| Weak area | Review |
|---|---|
| ACL ordering, placement, state, and counters | `labs/acl-basics/` |
| TACACS failure modes and local fallback | `labs/aaa-ops-troubleshooting/` |
| Control-plane classification, policing, and safe verification | `labs/copp-basics/` |
| Management source/interface restrictions and lockout prevention | `labs/management-access-control/` |
