---
title: "05 DNS Deep Dive"
---

!!! tip "Practice Lab"
    Turn a bare BIND9 server into an enterprise resolver — recursion with an open-resolver guard, conditional forwarding to AD DNS, split-horizon views, and reverse zones

!!! note "Platform"
    Docker Compose — custom `bind9:local`, `samba-ad:local`, and `workstation:local` images

{%
  include-markdown "../../../enterprise-it-101/labs/05-dns-deep-dive/README.md"
%}
