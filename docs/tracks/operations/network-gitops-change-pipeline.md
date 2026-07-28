---
title: network-gitops-change-pipeline
---

!!! tip "Practice / Troubleshooting Lab"
    Build a reviewed local network change pipeline, detect drift and partial
    pushes, and restore cEOS snapshots without hiding the evidence.

!!! note "Images"
    `ceos:4.35.2F` plus `network-gitops:local`:
    `docker build -t network-gitops:local labs/network-gitops-change-pipeline/`

{% include-markdown "../../../labs/network-gitops-change-pipeline/README.md" %}
