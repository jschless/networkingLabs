---
title: "07 File Shares & ACLs"
---

!!! tip "Practice Lab"
    Configure a Samba member file server with per-department shares whose access is driven by AD group membership, bridge SMB share ACLs to POSIX filesystem ACLs, and prove Kerberos keeps passwords off the wire

!!! note "Platform"
    Docker Compose — custom `samba-ad:local` (member mode) and `workstation:local` images

{%
  include-markdown "../../../enterprise-it-101/labs/07-file-shares/README.md"
%}
