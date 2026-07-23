# Feature Probe Record — carrier-ethernet-handoff

**Date:** 2026-07-23. **Decision:** documented fallback: cEOS is retained for CE UNI trunks; OVS 3.1.0 userspace is the provider NID/core.

| Item | Exact value |
|---|---|
| Host/kernel | Linux 5.15.0-181-generic |
| ContainerLab / Docker | 0.74.1 / 29.5.3 |
| cEOS | 4.35.2F-46221466.4352F |
| OVS image | carrier-ethernet-tools:1.0.0, Debian 12.12, OVS 3.1.0 |

Small cEOS probe (`containerlab deploy -t /tmp/carrier-ceos-probe.clab.yml`) took 22.43 s and 40,308 KiB controller RSS; the running node used 957.1 MiB. `switchport mode dot1q-tunnel` returned `Unavailable command (not supported on this hardware platform)` and `show ethernet cfm` returned `Invalid input`.

OVS probe used a one-node netdev datapath. `ovs-ofctl -O OpenFlow13 add-flow ... push_vlan:0x88a8,set_field:0x1c1c->vlan_vid,set_field:5->vlan_pcp` was accepted after using the OpenFlow present bit. CFM columns exist (`cfm_mpid`, `cfm_remote_mpids`, `cfm_health`) but this host lacks the OVS kernel module and the userspace datapath did not prove reliable CCM/LBM/LTM behavior. CFM is therefore evidence-only. Both disposable probes were destroyed with `containerlab destroy --cleanup`; no probe resources remained.
