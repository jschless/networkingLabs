# soc-elk-ingest — SIEM Ingest Pipeline

Normalize Zeek, Suricata, and YARA telemetry into a SIEM-style index model. This lab uses a lightweight local artifact store to keep the repo deployable without requiring a multi-container Elastic stack by default.

## Build And Deploy

```bash
docker build -t soc-endpoint:local images/soc-endpoint/
docker build -t soc-sensor:local images/soc-sensor/
docker build -t soc-attacker:local images/soc-attacker/

./scripts/lab.sh deploy soc-elk-ingest
./scripts/lab.sh check soc-elk-ingest
```

## Key Tasks

1. Review source telemetry in `/var/log/zeek`, `/var/log/suricata`, and `/var/log/yara` on `sensor`.
2. Review `/var/lib/soc-siem/indexes.json` on `siem`.
3. Map Zeek `id.orig_h`, Suricata `src_ip`, and YARA `file` into normalized analyst fields.
4. Define which records belong in `zeek-conn`, `suricata-alerts`, and `yara-hits`.
5. Replace the lightweight store with Logstash and Elasticsearch when host resources allow.

## Useful Commands

```bash
docker exec clab-soc-elk-ingest-siem jq . /var/lib/soc-siem/indexes.json
docker exec clab-soc-elk-ingest-sensor jq -s length /var/log/suricata/eve.json
```

## Outcome

You can explain the ingest contract for each telemetry source and verify that all three streams are represented in the SIEM layer.
