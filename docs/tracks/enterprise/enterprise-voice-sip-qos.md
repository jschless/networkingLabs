---
title: enterprise-voice-sip-qos
---

!!! tip "Practice Lab"
    Build live SIP registration/calls, expose bidirectional RTP, protect media with Linux QoS, and diagnose one-way audio across a stateful edge.

!!! note "Images and fidelity"
    Build `enterprise-voice-tools:1.0.0` with `docker build -t enterprise-voice-tools:1.0.0 labs/enterprise-voice-sip-qos/` and import licensed `ceos:4.35.2F`. Linux `tc`/nftables are the documented cEOS container-data-plane fallbacks.

{% include-markdown "../../../labs/enterprise-voice-sip-qos/README.md" %}
