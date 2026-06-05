---
title: "08 Group Policy & Config Mgmt"
---

!!! tip "Practice Lab"
    Create and link a Samba GPO (and see why Linux can't apply it), then enforce NTP, an SSH banner, and SSH hardening across hosts with idempotent Ansible playbooks — including drift detection with check mode

!!! note "Platform"
    Docker Compose — custom `ansible:local`, `samba-ad:local`, and `workstation:local` images

{%
  include-markdown "../../../enterprise-it-101/labs/08-group-policy/README.md"
%}
