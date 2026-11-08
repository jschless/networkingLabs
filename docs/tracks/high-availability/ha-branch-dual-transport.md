---
title: "HA Branch: Dual Router, Dual Transport"
---

!!! tip "Capstone Practice Lab"
    Two routers, two transports, one MLAG-meshed LAN — then fail every component and measure it

!!! note "Image"
    Arista cEOS — `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`; FRR helpers — `docker build -t frr-lab:local images/frr/`

{%
  include-markdown "../../../labs/ha-branch-dual-transport/README.md"
%}
