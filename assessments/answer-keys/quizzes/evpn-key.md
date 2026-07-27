# Answer Key — Data-Center EVPN

**Total:** 30 points

## A1 — Route types enable different traffic (3 points)

- Type 2 carries MAC/IP bindings; without it remote unicast endpoint resolution fails or
  falls back to flooding.
- Type 3 IMET carries VNI flood-list membership; without it BUM replication/VTEP
  discovery is incomplete.
- Type 5 carries IP prefixes; without it routed tenant or external prefixes are absent
  from importing VRFs.

One point per complete type and symptom.

## A2 — Attributes that must survive the spine (3 points)

`next-hop-unchanged` preserves the originating leaf VTEP so remote leaves tunnel to it,
not to a spine. `send-community extended` carries route targets; without them routes may
be visible but cannot be imported. RDs make otherwise identical NLRI unique and may be
per-leaf, while shared RT policy selects membership and therefore must match for intended
tenant import/export. (3)

## B1 — Visible NLRI, empty tenant RIB (8 points)

The EVPN table accepts the NLRI independently of the tenant VRF. PROD imports
`65020:59999`, which does not match received RT `65020:50010`; therefore no VRF route is
installed. Correct the import RT to `65020:50010`. Changing the RD only changes NLRI
uniqueness, not policy membership. Verify the EVPN path/RT, the PROD route and VNI/next
hop, then source a PROD endpoint test across sites while confirming DEV remains isolated.
(3+2+3)

## C1 — One tenant on one leaf (10 points)

```text
router bgp 65001
   neighbor 10.1.0.1 remote-as 65100
   neighbor 10.1.0.1 send-community extended
   neighbor 10.2.0.1 remote-as 65200
   neighbor 10.2.0.1 send-community extended
   address-family evpn
      neighbor 10.1.0.1 activate
      neighbor 10.2.0.1 activate
   vlan 10
      rd auto
      route-target both 65000:10010
      redistribute learned
   vrf TENANT-A
      rd 10.0.0.1:50001
      route-target import evpn 65000:50001
      route-target export evpn 65000:50001
      redistribute connected
```

Award 2 for peers/ASNs, 2 for extended-community transmission and EVPN activation, 3 for
the VLAN stanza, and 3 for the VRF stanza.

## D1 — Route between sites or stretch Layer 2? (6 points)

A routed type-5 DCI keeps broadcast and failure domains site-local, advertises PROD
prefixes explicitly, and avoids claiming live L2 mobility. Export policy permits only the
local PROD RT and imports the remote PROD RT at both border and consuming leaf; DEV is
denied. DCI loss withdraws remote type-5 routes while each site's local EVPN remains
healthy. Wrong RT: NLRI and VTEP reachability remain, but VRF import is absent. Underlay
failure: imported route may remain temporarily, but remote VTEP resolution/UDP 4789 path
fails. (6)

## Remediation table

| Question | Labs |
|---|---|
| A1, A2, C1 | `vxlan-evpn`, `spine-leaf` |
| B1, D1 | `dci-evpn-multisite`, `evpn-border-ceos` |
