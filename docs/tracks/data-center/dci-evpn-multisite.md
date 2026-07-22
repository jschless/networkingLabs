---
title: dci-evpn-multisite
---

!!! tip "Practice Lab"
    Design, observe, and troubleshoot a routed, type-5-only EVPN DCI between two independent fabrics.

!!! note "Images"
    `ceos:4.35.2F` (import with `scripts/build-images.sh ceos`) and `dci-endpoint:local` (`docker build -t dci-endpoint:local -f labs/dci-evpn-multisite/Dockerfile.endpoint labs/dci-evpn-multisite/`).

{%
  include-markdown "../../../labs/dci-evpn-multisite/README.md"
%}
