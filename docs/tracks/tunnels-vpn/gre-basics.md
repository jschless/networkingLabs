---
title: gre-basics
---

!!! tip "Practice Lab"
    **Build** — native cEOS GRE, visible encapsulation, OSPF over the overlay,
    and recursive endpoint-resolution diagnosis

!!! note "Image"
    Critical gateways: native Arista cEOS — run
    `./scripts/build-images.sh ceos`; see the
    [cEOS platform notes](../../platforms/ceos.md).
    Incidental hosts/transit: `docker build -t ops-lab:local images/ops-lab/`.

{%
  include-markdown "../../../labs/gre-basics/README.md"
%}
