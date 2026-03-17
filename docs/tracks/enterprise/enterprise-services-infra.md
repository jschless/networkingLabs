---
title: enterprise-services-infra
---

!!! tip "Practice Lab"
    DHCP relay, NTP, DNS, syslog, SNMP — supporting services

!!! note "Images"
    `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
    `docker build -t enterprise-services-infra:local labs/enterprise-services-infra/`
    `docker build -f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/`

{%
  include-markdown "../../../labs/enterprise-services-infra/README.md"
%}
