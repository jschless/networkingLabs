# Enterprise Access Security Quiz — Answer Key

**Total:** 30 points

## A. Control Foundations (6 points)

### A1. DHCP snooping, DAI, and IP Source Guard (3 points)

- 1 point: DHCP snooping distinguishes trusted DHCP-server paths from untrusted client ports and builds a binding table containing values such as IP address, MAC address, VLAN, and interface.
- 1 point: Dynamic ARP Inspection validates ARP messages against those bindings, while IP Source Guard validates client data-plane source addresses on the access port.
- 1 point: A statically addressed host may have no learned DHCP binding and can therefore be dropped unless an explicit static binding, ARP ACL, or narrowly scoped exception is configured.

### A2. 802.1X, MAB, and uRPF (3 points)

- 1 point: The supplicant and authenticator exchange EAP over LAN; the authenticator communicates with the authentication server using RADIUS, carrying the authentication exchange and authorization result.
- 1 point: MAC Authentication Bypass is useful for devices without a supplicant but is weaker because MAC addresses are observable and spoofable.
- 1 point: Strict uRPF requires the best return route for the source to use the receiving interface; loose uRPF requires only a route to the source. Loose mode or explicit source-prefix filtering is more appropriate where legitimate asymmetric routing is expected.

## B. Authentication and Authorization Troubleshooting (8 points)

### B1. Accepted identity, wrong operational VLAN (8 points)

- 2 points: An Access-Accept proves that identity authentication and the basic switch-to-RADIUS exchange succeeded.
- 2 points: The returned tunnel/VLAN attribute expresses the intended authorization result, while operational VLAN 99 shows that the switch did not apply it and used a fallback, guest, or locally configured VLAN instead.
- 2 points: Gives plausible causes, such as VLAN 20 not existing or not being permitted on the uplink, unsupported or malformed RADIUS attributes, an authorization/profile mismatch, or a local fallback policy overriding the result.
- 2 points: Checks both control and data planes: the RADIUS response attributes, switch authentication session details, operational VLAN, VLAN/trunk availability, DHCP behavior, and endpoint reachability.

Do not award full credit for treating the symptom as an invalid password after an Access-Accept has already been observed.

## C. Edge-Control Placement (10 points)

### C1. Secure access-layer policy (10 points)

- 2 points: Trust DHCP snooping only toward the legitimate DHCP server or relay path; keep client-facing ports untrusted.
- 2 points: Enable DHCP snooping and DAI for the intended client VLANs, with static bindings or narrowly scoped validation exceptions for legitimate static devices.
- 2 points: Apply IP Source Guard to client-facing access ports.
- 2 points: Apply 802.1X, with MAB only where required, and BPDU Guard on edge ports that should never receive switching control traffic.
- 2 points: Explains both trust mistakes: trusting a client port can admit rogue DHCP traffic and corrupt the binding model, while leaving the real server uplink untrusted can drop valid replies, prevent bindings, and cause subsequent DAI/IP Source Guard outages.

## D. Anti-Spoofing in an Asymmetric Design (6 points)

### D1. Strict uRPF on a multihomed edge (6 points)

- 2 points: Strict uRPF drops the packet because the best route back to the source points through edge B rather than the interface on edge A where the packet arrived.
- 2 points: Recommends loose uRPF, feasible-path validation where supported, or explicit source-prefix filters appropriate to the customer addressing and routing design.
- 1 point: States the tradeoff: relaxing strict reverse-path validation can accept a spoofed source when some route to that source exists, so filtering must remain deliberate.
- 1 point: Verifies the reverse-path lookup and drop counters, then tests both legitimate asymmetric flows and deliberately invalid source addresses.

## Remediation

| Weak area | Review |
|---|---|
| DHCP snooping, DAI, IP Source Guard, and edge protections | `labs/enterprise-access-security/` |
| 802.1X roles, RADIUS authorization, and dynamic VLANs | `labs/dot1x-nac/` |
| Switch-side 802.1X and MAB practice | `labs/dot1x-ceos-practice/` |
| Strict and loose reverse-path validation | `labs/urpf-antispoofing/` |
