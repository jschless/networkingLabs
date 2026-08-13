---
title: ipsec-basics
---

!!! tip "Build Lab"
    Build and prove native VyOS IKEv2 site-to-site IPsec, then diagnose an
    opaque proposal failure from underlay, SA, XFRM, counter, log, and capture
    evidence.

!!! note "Images"
    Learned gateways: `vyos:local` — one-time build from a VyOS ISO — see
    [VyOS platform notes](../../platforms/vyos.md). Incidental hosts/transit:
    `docker build -t ops-lab:local images/ops-lab/`.

{%
  include-markdown "../../../labs/ipsec-basics/README.md"
%}
