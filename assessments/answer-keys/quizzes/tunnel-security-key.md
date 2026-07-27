# Answer Key — GRE, IPsec & MTU

**Total:** 30 points

## A1 — Overlay without security (3 points)

GRE creates a routed encapsulation able to carry multicast and private addressing, but
provides neither encryption nor authentication. If the underlay route to the remote
tunnel endpoint resolves through the tunnel, sending the GRE packet requires the tunnel
that requires sending the GRE packet: recursive resolution makes the tunnel flap or
fail. (3)

## A2 — Read the security layers (3 points)

An IKE proposal, identity, DH, or PSK mismatch prevents the IKE SA. An ESP proposal or
selector mismatch permits IKE but leaves no usable child SA. NAT changes addresses and
breaks native ESP assumptions, so peers detect NAT and encapsulate ESP in UDP/4500 for
translation and stateful traversal. (3)

## B1 — Small packets work (8 points)

The largest inner packet is `1400 - 24 = 1376` bytes. A larger DF packet cannot be
fragmented; filtered ICMP prevents the sender learning the smaller path MTU, while small
pings never exceed it. Set tunnel MTU no higher than 1376. IPv4 TCP MSS is
`1376 - 20 - 20 = 1336`. Verify with DF probes immediately below and above the boundary
and with a representative large TCP transfer/capture showing no oversized GRE. (2 each)

## C1 — Choose the packet stack (6 points)

1. GRE protected by transport-mode IPsec: GRE carries multicast/routing; IPsec selectors
   match GRE between WAN endpoints. Transport mode protects that existing outer packet
   without adding a second outer IP header. (3)
2. Tunnel-mode or route-based IPsec: it directly protects the fixed LAN selectors; GRE
   adds no required capability. (1.5)
3. Plain GRE: appropriate only when the stated threat model accepts visible,
   unauthenticated payloads. (1.5)

## C2 — NAT-T firewall policy (4 points)

Forward/permit UDP/500 for initial IKE and UDP/4500 for NAT-T to the translated peer,
including return state and correct port forwarding. After NAT detection, capture shows
IKE/ESP-in-UDP on 4500 rather than native ESP. If only 4500 is blocked, initial exchange
may begin on 500 but NATed negotiation/data cannot complete; the IKE/child state remains
incomplete or unusable. (4)

## D1 — Stop at the failed layer (6 points)

One point each:

1. prove WAN routes, addresses, and bidirectional peer reachability;
2. inspect/capture UDP/500 and IKE logs/SA to validate proposal, identity, and auth;
3. inspect child SA, ESP proposal, and traffic-selector counters;
4. when NAT exists, verify translation plus UDP/4500 capture/firewall state;
5. verify protected-prefix routes point at the intended policy/tunnel and avoid recursive
   resolution;
6. generate source-specific endpoint traffic, inspect encryption counters/capture, and
   verify return forwarding from the remote LAN.

## Remediation table

| Question | Labs |
|---|---|
| A1 | `gre-basics`, `debug-gre-basics` |
| A2, C1, D1 | `ipsec-basics`, `gre-ipsec` |
| B1 | `mtu-pmtud-troubleshooting`, `gre-basics` |
| C2 | `opnsense-ipsec-nat-t` |
