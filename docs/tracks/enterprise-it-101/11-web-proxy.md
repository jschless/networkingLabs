---
title: "11 Web Proxy & Filtering"
---

!!! tip "Practice Lab"
    Put a Squid forward proxy in front of the web, authenticate every user transparently with Kerberos Negotiate (no password prompt), enforce per-AD-group web policy (engineering browses freely, finance is blocked from a site), read the access log attributing each request to a named user, and poison the proxy's service key to watch auth collapse

!!! note "Platform"
    Docker Compose — custom `squid-ad:local` (domain-joined Squid), `nginx:alpine` origins, and `samba-ad:local` / `workstation:local`

{%
  include-markdown "../../../enterprise-it-101/labs/11-web-proxy/README.md"
%}
