---
title: load-balancer-basics
---

!!! tip "Practice Lab"
    HAProxy in a DMZ: L4 vs L7 balancing, health checks, X-Forwarded-For, NAT-mode balancing with nftables, and an asymmetric-return-path break-it diagnosed from a packet capture

!!! note "Images"
    `docker build -t lb-lab:local labs/load-balancer-basics/` (no cEOS required)

{%
  include-markdown "../../../labs/load-balancer-basics/README.md"
%}
