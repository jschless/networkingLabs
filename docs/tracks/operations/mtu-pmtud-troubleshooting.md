---
title: MTU and PMTUD Troubleshooting
---

!!! tip "Guided Debug Lab"
    Diagnose a size-sensitive GRE outage with exact-size probes, bounded
    captures, native VyOS tunnel configuration, and bidirectional validation.

!!! note "Images"
    Learned edges use `vyos:local`; see the
    [VyOS platform notes](../../platforms/vyos.md). Incidental endpoints use
    `ops-lab:local` — `docker build -t ops-lab:local images/ops-lab/`.

{%
  include-markdown "../../../labs/mtu-pmtud-troubleshooting/README.md"
%}
