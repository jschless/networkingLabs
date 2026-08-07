---
title: anycast-dns
---

!!! tip "Build Lab"
    Build service-health-controlled routing-on-host: FRR resolver hosts export a filtered shared /32 to native cEOS routers, which select and forward to the closest healthy instance

!!! note "Images"
    Prepare `ceos:4.35.2F` with `scripts/build-images.sh ceos`, then build `frr-lab:local`, `ops-lab:local`, and `anycast-dns:local` with the commands in the lab

{%
  include-markdown "../../../labs/anycast-dns/README.md"
%}
