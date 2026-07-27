# Answer Key — WireGuard Topic Quiz

**Total:** 20 points

## A1 — Keys, endpoints, and allowed prefixes (4 points)

- The private key remains on its device; possession authenticates the public-key identity
  configured by peers. (1)
- `Endpoint` tells a peer where to send encrypted UDP; roaming peers can update learned
  endpoints after valid traffic. (1)
- `AllowedIPs` selects which outbound destinations use that peer and validates which
  inner source prefixes that peer may send. (1)
- A recent handshake proves key agreement/current peer transport, not correct routes,
  `AllowedIPs`, application policy, or end-to-end forwarding. (1)

## B1 — Handshake succeeds, overlay address fails (6 points)

- The peer keys and underlay transport work, but the hub assigns gw-a the wrong allowed
  /32. It therefore has no peer route for `.10` and rejects `.10` as an inner source. (3)
- Restore gw-a's hub-side `AllowedIPs` to `192.168.100.10/32`, ensuring no overlap with
  another peer. (1)
- Verify the hub peer/route selection and bidirectional sourced traffic through wg0;
  confirm recent handshake plus transfer counters and encrypted wire traffic. (2)

## C1 — Hub-and-spoke or mesh (5 points)

- Hub-and-spoke keeps each spoke at one peer and centralizes routing/policy/key inventory,
  but spoke traffic hairpins and the hub is a capacity/failure concentration. (2)
- Full mesh needs each site to maintain every other peer, endpoint, public key, and
  nonoverlapping `AllowedIPs`; ten sites require 45 peer relationships. It gives direct
  paths but materially increases rotation/change burden. (2)
- A defensible choice ties topology to east-west demand, site count, automation, NAT
  reachability, and hub redundancy rather than claiming one model is universally better.
  (1)

## D1 — Rotate one peer safely (5 points)

- Generate the new private key on the spoke and inventory its new public-key identity
  without exporting either private key. (1)
- Prestage a temporary second peer/address or coordinated maintenance cutover because one
  WireGuard peer record has one public key; avoid overlapping `AllowedIPs`. (1)
- Validate a handshake and bidirectional application traffic using the new identity,
  then remove the old peer/key. (1)
- Confirm all unrelated peers and routes remain unchanged and audit the identity mapping.
  (1)
- Roll back to the still-protected old peer if the new handshake, route, or service test
  fails before revocation. (1)

## Remediation

| Weak area | Review |
|---|---|
| Key identity, `AllowedIPs`, hub/mesh design, and peer lifecycle | `labs/wireguard/` |
