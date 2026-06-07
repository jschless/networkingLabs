---
title: "12 RADIUS & AD Integration"
---

!!! tip "Practice Lab"
    Run FreeRADIUS as the bridge between network gear and AD: authenticate users with PAP (LDAP bind), PEAP/MSCHAPv2 (validated against AD via ntlm_auth), and EAP-TLS (certificates, no password), return a dynamic VLAN by AD group, and break the shared secret to feel RADIUS's silent failure

!!! note "Platform"
    Docker Compose — custom `freeradius-ad:local` (domain-joined FreeRADIUS) and `samba-ad:local`

{%
  include-markdown "../../../enterprise-it-101/labs/12-radius/README.md"
%}
