---
title: zero-trust-secure-access
---

!!! tip "Practice Lab"
    Live OIDC claims, mTLS device signal, per-resource authorization, auditable decisions, and independent origin-bypass detection.

!!! note "Images"
    `docker build -t zt-access-tools:local labs/zero-trust-secure-access/` and `docker build -f labs/zero-trust-secure-access/Dockerfile.keycloak -t zt-keycloak:local labs/zero-trust-secure-access/` (pinned Python, BusyBox, and Keycloak bases).

{% include-markdown "../../../labs/zero-trust-secure-access/README.md" %}
