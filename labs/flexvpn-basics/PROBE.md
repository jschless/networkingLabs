# flexvpn-basics platform probe

## Decision

Retain the lab as a Build lab and accurately frame it as a **Linux strongSwan
analogue of Cisco FlexVPN concepts**, not literal Cisco FlexVPN or IOS syntax.
Linux remains in the critical gateway roles under platform exception (b): the
validated local cEOS and VyOS images do not implement Cisco FlexVPN, while the
local strongSwan image exposes executable IKEv2, kernel VTI, XFRM mark/policy,
ESP, and hub-hairpin behavior.

## Pre-remediation engineering probe supplied to this implementation

The main orchestration probe on the local host observed:

- strongSwan 5.9.8 on Linux 5.15 with working `ip_vti`;
- simultaneous hub/spoke `auto=start` plus `%unique` produced duplicate
  CHILD SAs with dynamic marks and unstable forwarding;
- a single initiated SA with deterministic mark `1` matching VTI key `1`
  established and forwarded;
- forwarding required strongSwan automatic table-220 routes to be disabled;
- public transit showed bidirectional ESP, and VTI packet counters increased.

That evidence settled the implementation: a passive hub (`auto=add` plus
`dpdaction=clear`), initiating/retrying spokes (`auto=start` plus
`dpdaction=restart`), deterministic marks `1` and `2`, matching VTI keys,
explicit routes, and `charon.install_routes` disabled. VTI does not mean “no
XFRM policies”: marked policies still perform encryption after routing selects
the interface.

## Reproduction questions

1. Does each spoke create exactly one IKE SA and one CHILD SA?
2. Do state and policy marks equal their VTI key in both directions?
3. Is table 220 empty while explicit main-table VTI routes forward?
4. Does transit expose ESP without readable private addresses?
5. Does one spoke-to-spoke flow increment both hub VTI legs?
