---
title: acl-basics
---

!!! tip "Build Lab"
    Build and verify a cEOS data-plane extended ACL, diagnose a wrong-interface
    attachment from counters, and add a narrow service exception.

!!! note "Images — mixed cEOS/Linux"
    `ceos:4.35.2F` for the learned transit router plus `ops-lab:local` for the
    three incidental Linux endpoints. Import cEOS and build the Linux image
    exactly as shown in the lab prerequisites.

{%
  include-markdown "../../../labs/acl-basics/README.md"
%}
