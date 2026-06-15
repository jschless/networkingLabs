---
title: enterprise-grand-capstone
---

!!! tip "Practice Lab"
    Cross-track crown jewel — cEOS campus bonded to real AD/RADIUS/DHCP/DNS services;
    802.1X → RADIUS → AD → dynamic VLAN → DHCP → DNS → Kerberos, then break it (4 planted faults)

!!! note "Image"
    Arista cEOS (`docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`) + Compose service images — built via `./gcap.sh build`

{%
  include-markdown "../../../labs/enterprise-grand-capstone/README.md"
%}
