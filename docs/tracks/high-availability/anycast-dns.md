---
title: anycast-dns
---

!!! tip "Practice Lab"
    Anycast DNS via routing-on-the-host: FRR on the servers advertises a shared /32 VIP by eBGP, a health-check watchdog withdraws it with the service, clients fail over in ~2 s

!!! note "Images"
    `docker build -t frr-lab:local images/frr/`, `docker build -t ops-lab:local images/ops-lab/`, and `docker build -t anycast-dns:local labs/anycast-dns/` (no cEOS required)

{%
  include-markdown "../../../labs/anycast-dns/README.md"
%}
