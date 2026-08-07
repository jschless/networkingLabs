# Network Assurance Platform Probe

Design-time probes were run before this remediation to determine which
platforms can produce each assurance signal honestly. These are capability
observations, not a post-remediation validation record.

## Environment

- cEOS: EOS `4.35.2F-46221466.4352F` (engineering build), build ID
  `6f39e5bb-e6c7-4637-b931-ecb30d43e034`
- Host kernel: `5.15.0-181`
- VyOS fallback: `2026.03.15-0031-rolling`

## Results

| Probe | Result | Design consequence |
|-------|--------|--------------------|
| cEOS routed forwarding | Passed | One native EOS router owns the data-plane event |
| cEOS SNMPv2c and SNMPv3 authPriv | Passed | Poll native device state and counters with numeric OIDs |
| cEOS bidirectional monitor session | Passed; both request and reply were captured | Use Ethernet1 as source and Ethernet4 as the sensor feed |
| cEOS native syslog | Passed; Ethernet2 down/up produced native `LINEPROTO` events | Use EOS logging rather than fabricated Linux messages |
| cEOS sampled IPFIX | Templates/options exported, but 40 hardware samples produced 40 hardware/software differences and zero flow records | Do not claim native cEOSLab IPFIX data records |
| cEOS native sFlow | Version 5 counter datagrams exported, but zero packet samples | Do not claim native cEOSLab sampled-flow support |
| VyOS flow-accounting fallback | Syntax was accepted, but commit failed while loading `ipt_NETFLOW`; module tree was built for `6.6.128-vyos`, not the `5.15.0-181` host kernel | Do not use VyOS as a nominal exporter in this environment |
| External `softflowd` sensor observing native SPAN | Passed; genuine NetFlow v9 records contained both directions at roughly 1,966/1,967 packets and 2.8 MB per direction | Use a non-inline sensor and describe the shared SPAN dependency explicitly |

Small bursts were not a deterministic flow-export trigger because packets can
remain in libpcap batching. The lab therefore uses a bounded 2,000-packet ICMP
burst, an explicit `expire-all`, and one five-second `nfcapd` rotation.
