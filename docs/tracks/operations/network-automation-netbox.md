---
title: network-automation-netbox
---

!!! tip "Capstone Lab"
    NetBox capstone: relational DCIM/IPAM, cable-validated native rendering,
    explicit field ownership, idempotent deployment, and bounded reconciliation

!!! note "Images"
    `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
    `docker build -t netbox-automation:local labs/network-automation-netbox/`

!!! warning "Resources and credentials"
    Budget about 6 GiB of RAM. All `admin`/database/NetBox secrets are
    disposable local bootstrap values, not production guidance.

{%
  include-markdown "../../../labs/network-automation-netbox/README.md"
%}
