---
title: global-application-delivery
---

!!! tip "Practice Lab"
    Build and troubleshoot two-site application delivery with real HAProxy,
    CoreDNS, resolver TTLs, TLS/SNI, persistence, cache, and a safe WAF seam.

!!! note "Sequence"
    Complete `load-balancer-basics` and the High Availability track's
    `anycast-dns` lab first. This lab combines and extends those mechanisms.

!!! note "Image"
    `global-delivery:local` — `docker build -t global-delivery:local labs/global-application-delivery/`
    (no cEOS required; pinned Alpine/CoreDNS bases).

{% include-markdown "../../../labs/global-application-delivery/README.md" %}
