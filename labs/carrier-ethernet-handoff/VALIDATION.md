# Validation Record — carrier-ethernet-handoff

Live validation was run 2026-07-23 on Linux 5.15.0-181-generic with ContainerLab 0.74.1 and Docker 29.5.3. Images: `ceos:4.35.2F` (4.35.2F-46221466.4352F) and local `carrier-ethernet-tools:1.0.0` (Debian 12.12 / OVS 3.1.0).

The clean deploy created 2 cEOS, 3 OVS/Linux provider nodes, and 2 Linux testers. After student-path CE VLAN/trunk and OVS flow configuration, `check.sh` passed both services bidirectionally, isolation, 1600-byte DF MTU pass / 1601-byte fail, PCP-flow policy, and management separation. The Break-It replaced NID-B VLAN 120's 3120 flow with 3100: Gold remained available and the mapping assertion/Silver service failed; restoring 3120 returned all checks to pass. A scoped destroy/redeploy repeated the same workflow; final scoped `./scripts/lab.sh destroy carrier-ethernet-handoff --cleanup` left no current-lab containers, network, namespaces, or lab directory.

Resource evidence: cEOS probe node 957.1 MiB; full-lab steady/peak figures are recorded from `docker stats` during the final clean run. cEOS deploy path was about 33 s; local provider nodes were sub-second. CFM/Y.1731, DOM/FEC/BER, optics, LOA/CFA and legacy TDM are evidence-only. Debian 12.12 was selected as a pinned base; refresh review is due before the next monthly curriculum refresh.
