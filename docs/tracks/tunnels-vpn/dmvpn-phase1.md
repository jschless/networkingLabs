---
title: dmvpn-phase1
---

!!! tip "Build Lab"
    Build and diagnose hub-transit DMVPN Phase 1 with native VyOS mGRE,
    NHRP, OSPF, service routes, and bounded packet evidence.

!!! note "Images and prerequisites"
    Critical routers use `vyos:local`; the incidental WAN bridge uses
    `ops-lab:local`. Complete `gre-basics` and `ospf-multiarea` first. See
    [VyOS platform notes](../../platforms/vyos.md) and
    [Getting Started](../../getting-started.md).

{%
  include-markdown "../../../labs/dmvpn-phase1/README.md"
%}
