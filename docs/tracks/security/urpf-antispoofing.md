---
title: urpf-antispoofing
---

!!! tip "Build Lab"
    Configure and prove VyOS strict and loose unicast RPF with one-way packet
    capture, route asymmetry, and live drop counters.

!!! note "Images"
    Learned router: `vyos:local`; see the
    [VyOS platform notes](../../platforms/vyos.md). Incidental endpoints:
    `ops-lab:local` — `docker build -t ops-lab:local images/ops-lab/`.

{%
  include-markdown "../../../labs/urpf-antispoofing/README.md"
%}
