# Answer Key — DMVPN

**Total:** 20 points

## A1 — Three phases, two kinds of scaling (4 points)

Phase 1 sends all spoke traffic through the hub. Phase 2 uses NHRP redirect/shortcut for
direct spoke tunnels but advertises full remote spoke routes with the remote tunnel next
hop. Phase 3 also builds direct shortcuts, while the hub advertises a summary and NHRP
installs on-demand more-specific routes. Full credit requires all paths, Phase-2 detail,
and Phase-3 summary behavior. (4)

## B1 — A specific appears after traffic (6 points)

This is Phase 3. The first packet matches the /16 and reaches the hub; the hub sends an
NHRP redirect, spoke1 resolves spoke2's tunnel-to-NBMA mapping, and later packets take the
direct shortcut. Longest-prefix match makes the /24 beat the /16 independently of OSPF
administrative preference. Without `shortcut`, reachability remains through the summary
and hub, but direct-path efficiency is lost. (3+1+2)

## C1 — Phase 3 spoke essentials (5 points)

```text
set protocols nhrp tunnel tun0 network-id '1'
set protocols nhrp tunnel tun0 nhs tunnel-ip '172.16.0.1' nbma '10.0.0.1'
set protocols nhrp tunnel tun0 map tunnel-ip '172.16.0.1' nbma '10.0.0.1'
set protocols nhrp tunnel tun0 multicast '10.0.0.1'
set protocols nhrp tunnel tun0 shortcut
set protocols ospf parameters router-id '10.0.0.11'
set protocols ospf area 0 network '172.16.0.11/32'
set protocols ospf area 0 network '192.168.1.0/24'
set protocols ospf interface tun0 network 'point-to-multipoint'
```

Award one point each for network/NHS mapping, multicast/shortcut, router ID and tunnel
network, LAN advertisement, and point-to-multipoint mode.

## D1 — The hub is not always in the data path (5 points)

The existing spoke1-spoke2 shortcut continues until its NHRP entry expires because its
data plane is direct. New spoke1-spoke3 resolution fails immediately because the hub is
the NHS/redirect broker and routing control-plane anchor. After aging, spoke2 also fails
to re-resolve. Check routes plus `show ip nhrp`, and compare traceroute/capture for the
existing versus new conversation. (5)

## Remediation table

| Question | Labs |
|---|---|
| A1 | `dmvpn-phase1`, `dmvpn-phase2`, `dmvpn-phase3` |
| B1, C1 | `dmvpn-phase3` |
| D1 | `dmvpn-phase2`, `dmvpn-phase3` |
