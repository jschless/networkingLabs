---
title: k8s-fabric
---

!!! tip "Practice Lab"
    A two-node k3s cluster peers to a Top-of-Rack router with MetalLB (BGP mode); LoadBalancer VIPs become /32 routes, ECMP across nodes, and externalTrafficPolicy changes the advertisement itself

!!! note "Images"
    `docker build -t frr-lab:local images/frr/` and `docker build -t ops-lab:local images/ops-lab/`; the k3s, MetalLB, and nginx images pull from the internet at deploy time (no cEOS required)

{%
  include-markdown "../../../labs/k8s-fabric/README.md"
%}
