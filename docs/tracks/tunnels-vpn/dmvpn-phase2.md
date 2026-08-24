---
title: dmvpn-phase2
---

!!! tip "Reference / Observation Lab"
    Compare preserved remote-spoke BGP next hops with the current VyOS/FRR
    `/32` NHRP implementation, then prove that direct forwarding depends on
    Phase 3-style redirect/shortcut signaling rather than classic Phase 2
    ordinary next-hop resolution.

!!! note "Images and prerequisites"
    Critical routers use `vyos:local`; the incidental WAN bridge uses
    `ops-lab:local`. Complete `dmvpn-phase1` and `bgp-basics` first. See
    [VyOS platform notes](../../platforms/vyos.md) and
    [Getting Started](../../getting-started.md).

{%
  include-markdown "../../../labs/dmvpn-phase2/README.md"
%}
