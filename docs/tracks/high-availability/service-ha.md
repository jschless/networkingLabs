---
title: service-ha
---

!!! tip "Practice Lab"
    Active/backup stateful firewall pair: keepalived floats the VIPs, conntrackd replicates the connection-tracking table, and a long-lived TCP flow dies on failover without state sync and survives with it

!!! note "Image"
    `docker build -t service-ha:local labs/service-ha/` (no cEOS required)

{%
  include-markdown "../../../labs/service-ha/README.md"
%}
