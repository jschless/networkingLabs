---
title: k8s-fabric
---

!!! tip "Build Lab"
    A two-node k3s cluster peers to a Top-of-Rack router with MetalLB (BGP mode); LoadBalancer VIPs become /32 routes, ECMP across nodes, and externalTrafficPolicy changes the advertisement itself

!!! note "Images"
    Prepare the canonical `ceos:4.35.2F` tag (EOS 4.35.2F on amd64;
    cEOSarm 4.36.1F on arm64) and build `ops-lab:local`. k3s v1.30.6+k3s1,
    MetalLB v0.14.8 controller/speaker, and nginx 1.27-alpine are pinned by
    exact digest and pull at deploy when absent locally.

{%
  include-markdown "../../../labs/k8s-fabric/README.md"
%}
