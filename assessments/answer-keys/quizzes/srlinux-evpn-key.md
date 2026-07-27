# Answer Key — SR Linux VXLAN-EVPN Operations Topic Quiz

**Total:** 20 points

## A1 — Control BUM and unicast forwarding (4 points)

- Type-3 IMET advertises VTEP participation and establishes the BUM flooding set before
  remote unicast MACs are known. (1)
- Type-2 advertises learned MAC and optional IP reachability for control-plane unicast
  forwarding. (1)
- The routed underlay must reach each VTEP loopback used as VXLAN source/destination.
  (1)
- The VNI binds the VXLAN segment to the SR Linux MAC-VRF and its BGP-EVPN instance. (1)

## B1 — Routes exchange, hosts do not (6 points)

- BGP EVPN sessions and routes can remain established globally because the peer/control
  relationship is healthy, but VNI 100 and 200 represent different overlay segments.
  (3)
- Restore vtep2's intended MAC-VRF/VXLAN VNI to 100. (1)
- Verify matching tunnel/MAC-VRF state and remote MAC entry, then capture UDP 4789 and
  prove host bidirectional traffic. (2)

## C1 — Verify a remote MAC (5 points)

1. Host ARP enters the local MAC-VRF and initially requires BUM delivery. (1)
2. Type-3 IMET state identifies remote VTEPs for that flood. (1)
3. The remote VTEP receives the frame, learns the source MAC, and originates Type-2.
   (1)
4. The route reflector distributes Type-2 and the local VTEP installs a remote
   control-plane MAC toward the remote VTEP. (1)
5. Subsequent frames use VXLAN UDP 4789 unicast and the reply completes end to end. (1)

## D1 — Translate concepts, not commands (5 points)

- SR Linux uses native tunnel-interface/MAC-VRF/BGP-EVPN objects; Linux/FRR composes
  kernel bridge/VXLAN devices and FRR control state. (2)
- SR Linux natively reconciles/prefer EVPN-learned MACs, while the Linux design may need
  data-plane learning disabled to avoid conflicting state. (1)
- SR Linux uses a modeled candidate/commit workflow rather than shell plus daemon CLI.
  (1)
- On either platform, underlay VTEP reachability, EVPN Type-3/Type-2 state, VNI mapping,
  remote MAC/FDB, VXLAN capture, and host traffic must agree. (1)

## Remediation

| Weak area | Review |
|---|---|
| SR Linux MAC-VRF/VNI, EVPN routes, native learning, and verification | `labs/vxlan-evpn-srlinux/` |
