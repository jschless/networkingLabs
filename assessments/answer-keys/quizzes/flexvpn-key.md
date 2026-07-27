# Answer Key — FlexVPN and Route-Based IPsec Topic Quiz

**Total:** 20 points

## A1 — Bind a route to an SA (4 points)

- IKEv2 authenticates peers and negotiates the IPsec CHILD_SA/XFRM state. (1)
- The VTI is the routed point-to-point interface; its key becomes an XFRM mark. (1)
- A route sends selected prefixes into that VTI, and a matching marked SA encrypts them.
  (1)
- Correct policy-bypass/`disable_policy` handling prevents generic XFRM policy checks from
  interfering with the marked VTI path. (1)

## B1 — Established is not forwarding (6 points)

- IKE uses peer identity/credentials and can establish, but the CHILD_SA mark 4 does not
  match VTI key 3, so traffic routed into the VTI does not bind to that SA. (3)
- Correct the VTI key to 4, or deliberately make both ends' unique mark/key consistent,
  then confirm route and `disable_policy`. (1)
- Capture plaintext on vti0 and ESP on the WAN for the same test flow, while checking
  XFRM packet counters and hub-VTI/application reachability. (2)

## C1 — Add dynamic routing (5 points)

- Run a separate adjacency over each point-to-point VTI, using matching tunnel addresses
  and point-to-point network type. (1)
- Advertise only each site's approved LAN prefixes and filter defaults/internal
  infrastructure as required. (1)
- Loss of SA/VTI adjacency should withdraw routes rather than leave stale statics. (1)
- Verify IGP neighbor, learned route/next hop, XFRM/VTI counters, and bidirectional
  application traffic. (1)
- Protect the routing session and avoid accidentally redistributing underlay/default
  routes into the overlay. (1)

## D1 — Fifty spokes and heavy east-west traffic (5 points)

- The hub holds a VTI, SA state, routes/adjacency, and policy per spoke; configuration and
  rekey/failure events grow roughly with spoke count. (2)
- East-west packets are decrypted then re-encrypted at the hub, consuming CPU/bandwidth
  and adding hub-path latency/failure dependency. (1)
- The model remains defensible for moderate scale, central inspection, and low east-west
  demand with redundant sized hubs and automation. (1)
- High spoke count or heavy locality-sensitive east-west traffic favors dynamic
  spoke-to-spoke shortcuts, scalable overlay control, or regional hubs. (1)

## Remediation

| Weak area | Review |
|---|---|
| IKEv2/VTI/XFRM binding, routed verification, and hub scaling | `labs/flexvpn-basics/` |
