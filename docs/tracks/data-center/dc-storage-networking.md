---
title: dc-storage-networking
---

!!! tip "Practice Lab"
    Build authenticated redundant iSCSI paths, multipath failover, exact jumbo
    MTU validation, bounded congestion scheduling, and the ping-works/I/O-stalls case.

!!! note "Image and host prerequisite"
    `dc-storage-tools:1.0.0` — `docker build -t dc-storage-tools:1.0.0 labs/dc-storage-networking/`.
    Linux/amd64 with `/dev/kvm` is required for the safe isolated initiator.

{% include-markdown "../../../labs/dc-storage-networking/README.md" %}
