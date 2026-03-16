---
title: aaa-ops-troubleshooting
---

!!! tip "Practice Lab"
    TACACS reachability, shared secrets, local fallback, break-glass access

!!! note "Images"
    `docker build -t ops-lab:local images/ops-lab/`
    `docker build -f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/`
    `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`

{%
  include-markdown "../../../labs/aaa-ops-troubleshooting/README.md"
%}
