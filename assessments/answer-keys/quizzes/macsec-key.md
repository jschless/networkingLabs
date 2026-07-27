# Answer Key — MACsec Link Security Topic Quiz

**Total:** 20 points

## A1 — Protect one link (4 points)

- MACsec protects Ethernet frames at Layer 2 on each enabled physical hop; each
  intermediate hop terminates and would need its own MACsec relationship. (1)
- IPsec protects Layer-3 traffic between IP security endpoints and can span intervening
  routers, but does not directly protect non-IP Ethernet control/data on each local hop.
  (1)
- MACsec is commonly placed on exposed campus, data-center, or inter-building Ethernet
  links where wire tapping is in scope. (1)
- MKA authenticates/connects members and manages rotating Secure Association Keys from
  shared connectivity-association material. Peers must use compatible CAK/CKN identity
  and policy. (1)

## B1 — Control frames repeat, protected traffic never starts (6 points)

1. `0x888e` is EAPOL/MKA control traffic, while `0x88e5` identifies MACsec-protected data.
   Repeated control with no protected data and mismatched CKNs localizes failure to MKA
   connectivity-association agreement, before a usable secure channel. (3)
2. The plain link proves the endpoints and basic IP/application test work independently;
   it narrows the fault to the MACsec link rather than general node failure. (1)
3. Restore the intended matching CKN/CAK configuration on the incorrect peer. Verify MKA
   and secure-channel/interface counters become active, capture `0x88e5` on physical
   `eth1`, and observe decrypted ICMP only on `macsec0`. Any two verification boundaries
   earn the 1 remaining verification point. (2)

## C1 — Place MACsec from the threat model (5 points)

- Protect exposed inter-building fiber because an attacker with physical access can
  otherwise observe/inject Ethernet traffic between trusted devices. (2)
- Trusted in-rack links may omit MACsec when physical controls and performance/operations
  make the residual tap risk acceptable; protect them when tenant/regulatory/threat
  requirements say otherwise. (1)
- MACsec is not an end-to-end Internet WAN solution because every intervening Ethernet
  hop would terminate it; use an end-to-end Layer-3/application protection mechanism
  there. (1)
- A protected link still exposes outer Ethernet information needed for delivery and
  MACsec framing/timing; the inner payload is encrypted in confidentiality mode.
  Visibility of VLAN tags depends on placement/platform handling and must be verified
  rather than assumed. (1)

## D1 — Rotate keys safely (5 points)

- Pre-stage compatible new connectivity-association/key material using the platform's
  supported key-chain/overlap method or coordinate both ends through a protected
  maintenance procedure; do not leave permanent mismatched CKNs. (1)
- Observe MKA peer/live secure-association state and confirm the new association becomes
  active before retiring the old material. (1)
- Run continuous traffic and watch protected packet, invalid-tag, late/replay, and drop
  counters during the transition. (1)
- Exercise the configured replay window with controlled reordering only where safe, and
  confirm genuine replays are rejected without normal reordering causing unacceptable
  loss. (1)
- Roll back if MKA loses its peer, protected data stops, or invalid/replay counters rise
  unexpectedly; then re-verify wire-side encryption and decrypted-interface delivery.
  (1)

## Remediation

| Weak area | Review |
|---|---|
| MACsec scope, MKA, packet-capture boundaries, key agreement, and replay behavior | `labs/macsec-basics/` |
