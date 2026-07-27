# Answer Key — Remote Access and Zero Trust Topic Quiz

**Total:** 30 points

## A1 — Tunnel identity versus application authorization (3 points)

- A recent WireGuard handshake proves possession of the configured peer private key and
  current encrypted transport with that peer. (1)
- It does not prove a human identity, device posture, group membership, or entitlement
  to every network behind the concentrator. (1)
- Enforce per-peer/tunnel-source access on the assigned VPN interface/firewall and apply
  resource-level identity/device policy at the PEP or application boundary. (1)

## A2 — Split tunnel and resource access (3 points)

- Split tunnel installs only selected enterprise prefixes through the VPN; Internet and
  normally DNS not explicitly selected remain on the local path, reducing backhaul but
  limiting enterprise inspection. (1)
- Full tunnel selects the default through the concentrator, centralizing Internet/DNS
  policy at the cost of capacity, latency, and a larger outage domain. (1)
- A VPN subnet is only a network location. Resource authorization must validate the
  intended identity, group/audience, device signal, route, and session policy rather than
  trusting all tunnel occupants equally. (1)

## B1 — Connected contractor, denied application (8 points)

1. The recent handshake, selected `wg0` route, and successful jump-host SSH prove tunnel
   establishment and routed reachability. The application-specific denial is downstream
   policy, not a generic crypto or route failure. (3)
2. The VPN-interface firewall intentionally denies contractor address
   `10.250.0.20` to the corporate application on TCP 8443 while permitting the jump host.
   (2)
3. Confirm the contractor's expected role/change record; inspect exact ordered rule and
   hit/log counter; test the permitted jump-host tuple and denied app tuple; and compare
   a developer peer that is entitled to the app. Any three earn credit. (3)

## C1 — Protect finance by identity, device signal, and path (10 points)

- Validate token signature/active state, issuer, audience for the PEP, expiry, and
  `finance` group rather than trusting a decoded payload alone. (2)
- Require a trusted managed-client certificate through mTLS in addition to the finance
  identity; describe it as a device credential, not complete live posture. (2)
- Define `/partner` as a separate resource rule requiring the partner group even if it
  maps to the same origin, and deny partner/operations identities at `/finance`. (2)
- Permit remote clients only to the PEP/identity dependencies and allow only PEP-to-origin
  service traffic, preventing direct origin bypass. (2)
- Test managed finance permit, finance token without device certificate deny, wrong-group
  denies for each route, expired token deny, and unauthenticated direct-origin deny with
  correlated decision/request logs. (2)

## D1 — Revoke one principal without breaking everyone (6 points)

- Removing/disabling one WireGuard peer stops that key's future handshakes and tunnel
  traffic while other peers remain configured. Existing observations must account for
  handshake/keepalive and state expiration. (2)
- Expiring/revoking an application token or device certificate acts at PEP validation
  according to token lifetime, introspection/cache, certificate validation, and existing
  session behavior; it need not remove the network tunnel. (2)
- Prove the targeted identity/key loses new access, an unrelated principal retains its
  tunnel and allowed service, denied direct paths remain denied, and logs identify the
  revocation reason/timing. Shared route removal or concentrator shutdown creates a
  broad outage and does not demonstrate selective lifecycle control. (2)

## Remediation

| Weak area | Review |
|---|---|
| Per-peer tunnel identity, split routing, firewall authorization, and revocation | `labs/opnsense-remote-access-concentrator/` |
| Token/device/resource policy, session lifetime, and origin-bypass prevention | `labs/zero-trust-secure-access/` |
