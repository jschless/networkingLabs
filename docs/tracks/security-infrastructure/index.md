# Security Infrastructure Track

Ten labs covering SOC infrastructure: DMZ visibility, Zeek protocol logs, Suricata IDS, YARA file analysis, SIEM ingest, HVT dashboards, packet search, adversary simulation, threat intel, and incident response workflow.

| Lab | Type | Tools | What You Learn |
|-----|------|-------|----------------|
| [soc-dmz-foundation](soc-dmz-foundation.md) | Practice | containerlab, Linux, tcpdump | DMZ topology, routed segmentation, mirror feeds |
| [soc-zeek-analysis](soc-zeek-analysis.md) | Practice | Zeek-style logs, jq | Protocol logging, connection records, notices |
| [soc-suricata-ids](soc-suricata-ids.md) | Practice | Suricata, EVE JSON | IDS alert records, rule-to-event mapping |
| [soc-yara-file-pipeline](soc-yara-file-pipeline.md) | Practice | YARA, file extraction | Benign file scanning and hit logging |
| [soc-elk-ingest](soc-elk-ingest.md) | Practice | SIEM ingest model | Normalizing Zeek, Suricata, and YARA streams |
| [soc-kibana-hvt-dashboard](soc-kibana-hvt-dashboard.md) | Practice | Dashboard artifacts | HVT monitoring panels and analyst pivots |
| [soc-arkime-pcap](soc-arkime-pcap.md) | Practice | Arkime-style sessions, PCAP | Packet search, evidence, and retention tradeoffs |
| [soc-adversary-simulation](soc-adversary-simulation.md) | Practice | ATT&CK mapping | Detection coverage and gap analysis |
| [soc-threat-intel-misp](soc-threat-intel-misp.md) | Practice | MISP-style IOCs | IOC-to-rule operationalization |
| [soc-ir-case-management](soc-ir-case-management.md) | Capstone | TheHive-style case workflow | End-to-end incident response timeline |

## Platform Notes

- Build the shared images once:
  - `docker build -t soc-endpoint:local images/soc-endpoint/`
  - `docker build -t soc-sensor:local images/soc-sensor/`
  - `docker build -t soc-attacker:local images/soc-attacker/`
- The early labs are lightweight and use local containers.
- SIEM, Arkime, MISP, and case-management labs include deterministic local artifacts by default so they remain deployable on modest lab hosts.
- Replace the lightweight artifacts with full upstream stacks when host RAM and disk allow.
