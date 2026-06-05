---
title: "03 Certificate Authority & PKI"
---

!!! tip "Practice Lab"
    Smallstep internal CA, LDAPS on the DC, and the trust chain — break it and watch the error blame the wrong layer

!!! note "Platform"
    Docker Compose — custom `samba-ad:local` / `workstation:local` images + `smallstep/step-ca`

{%
  include-markdown "../../../enterprise-it-101/labs/03-certificate-authority/README.md"
%}
