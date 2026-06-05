---
title: "06 DHCP & Dynamic DNS"
---

!!! tip "Practice Lab"
    Configure an ISC Kea DHCP server with options and reservations, watch the DORA exchange on the wire, and wire up TSIG-authenticated Dynamic DNS so leased clients become resolvable automatically

!!! note "Platform"
    Docker Compose — custom `kea:local`, `bind9:local`, `samba-ad:local`, and `workstation:local` images

{%
  include-markdown "../../../enterprise-it-101/labs/06-dhcp-dynamic-dns/README.md"
%}
