---
title: suzieq-network-observability
---

!!! tip "Reference Lab"
    Use SuzieQ to observe, query, and assert network health across a three-router OSPF fabric — device discovery, interface state, LLDP topology mapping, path tracing, and automated health assertions.

!!! note "Images"
    `docker build -t suzieq-lab:local labs/suzieq-network-observability/`
    `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`

{%
  include-markdown "../../../labs/suzieq-network-observability/README.md"
%}
