---
title: enterprise-dmz-capstone
---

!!! tip "Capstone Lab"
    Build a screened-subnet DMZ from scratch with dual firewalls, DNAT, and SNAT

!!! note "Images"
    Arista cEOS — `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`

    `dmz-lab:local` — `docker build -t dmz-lab:local labs/enterprise-dmz-capstone/`

{%
  include-markdown "../../../labs/enterprise-dmz-capstone/README.md"
%}
