---
title: black-core-routing
---

!!! tip "Capstone Lab"
    Conceptual black-core routing lab with explicit red/plaintext services, inline encryptor stand-ins, a black/ciphertext core, and packet-capture proof.

!!! note "Images"
    VyOS: `docker build -t vyos:local -f Dockerfile.vyos .`

    Support image: `docker build -t black-core-tools:local labs/black-core-routing/`

{%
  include-markdown "../../../labs/black-core-routing/README.md"
%}
