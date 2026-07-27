---
title: ot-zone-conduit
---

!!! tip "Practice Lab"
    Build and troubleshoot safety-aware IT/IDMZ/cell conduits with synthetic
    Modbus/TCP, time-bounded jump maintenance, and passive Suricata evidence.

!!! note "Image and safety boundary"
    Build `ot-zone-tools:1.0.0` with
    `docker build -t ot-zone-tools:1.0.0 labs/ot-zone-conduit/`. The image uses a
    digest-pinned Ubuntu 24.04 base and PyModbus 3.11.3. All process values and
    credentials are synthetic; no real industrial system is targeted.

{% include-markdown "../../../labs/ot-zone-conduit/README.md" %}
