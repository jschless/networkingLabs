# soc-elk-ingest — SIEM Ingest Pipeline

Normalize Zeek, Suricata, and YARA telemetry into a SIEM-style index model. This lab uses a lightweight local artifact store to keep the repo deployable without requiring a multi-container Elastic stack by default.


## How to use this lab

This is a **practice analysis lab**. The environment and evidence are
pre-built; your job is to *investigate*, not to follow a script. For each
task, **form a hypothesis about what the logs/PCAP will show before you
query them**, then run the filter and compare. The challenge questions push
you from "find the indicator" to "explain and respond."
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

## Challenge questions

No answers provided — reason them through.

1. Parsing/normalizing at ingest (grok, ECS fields) is where bad data becomes invisible later. Pick a field and show how a wrong parse silently breaks a downstream detection query.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
