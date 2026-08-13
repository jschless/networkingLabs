---
title: gre-ipsec
---

!!! tip "Build Lab"
    Build native VyOS transport-mode IPsec around GRE, prove encryption at two
    observation layers, and diagnose a green-connectivity confidentiality loss.

!!! note "Images"
    Learned gateways: `vyos:local` — one-time build from a VyOS ISO — see
    [VyOS platform notes](../../platforms/vyos.md). Incidental hosts/transit:
    `docker build -t ops-lab:local images/ops-lab/`.

{%
  include-markdown "../../../labs/gre-ipsec/README.md"
%}
