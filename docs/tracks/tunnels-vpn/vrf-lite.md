---
title: vrf-lite
---

!!! tip "Build Lab"
    Build native VRF-Lite on cEOS, prove dedicated-link isolation, authorize one bidirectional `/32` share, and diagnose an inactive cross-VRF static

!!! note "Images"
    Import Arista cEOS with `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F` and build the four incidental endpoints with `docker build -t ops-lab:local images/ops-lab/`.

{%
  include-markdown "../../../labs/vrf-lite/README.md"
%}
