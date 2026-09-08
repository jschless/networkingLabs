---
title: dmvpn-phase3-ipsec-capstone
---

!!! tip "Capstone Lab"
    DMVPN Phase 3 with in-lab PKI and certificate-based IPsec (VyOS)

!!! note "Image"
    Learned routers: `vyos:local` — one-time build from a VyOS ISO — see
    [VyOS platform notes](../../platforms/vyos.md). Intrinsic CA:
    `docker build -t dmvpn-pki:local labs/dmvpn-phase3-ipsec-capstone/`.
    Incidental WAN bridge: `docker build -t ops-lab:local images/ops-lab/`.

{%
  include-markdown "../../../labs/dmvpn-phase3-ipsec-capstone/README.md"
%}
