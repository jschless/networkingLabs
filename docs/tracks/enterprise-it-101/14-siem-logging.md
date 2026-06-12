---
title: "14 SIEM & Security Logging"
---

!!! tip "Practice Lab"
    Stand up a Wazuh SIEM manager and turn the hosts you built earlier into sensors: enroll agents, onboard the SSH and Active Directory audit logs, write your own correlation rules for failed logins and new-account creation, fire an automatic firewall block at a brute-forcer, and watch a file change in real time — then find the SIEM's blind spots.

!!! note "Platform"
    Docker Compose — `wazuh/wazuh-manager:4.14.5` + custom `samba-ad-wazuh:local` / `workstation-wazuh:local`

{%
  include-markdown "../../../enterprise-it-101/labs/14-siem-logging/README.md"
%}
