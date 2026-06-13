---
title: "15 Backup & Disaster Recovery"
---

!!! tip "Practice Lab"
    Stand up a BorgBackup server, design encrypted deduplicated backups for the two most unforgivable things to lose — the AD database and the CA's private key — then destroy both on purpose and bring them back, verifying each restore against known data. Includes a recovery trap, scheduled backups with retention pruning, and a lost-passphrase drill.

!!! note "Platform"
    Docker Compose — custom `samba-ad-backup:local` / `backup-server:local` + `smallstep/step-ca`

{%
  include-markdown "../../../enterprise-it-101/labs/15-backup-recovery/README.md"
%}
