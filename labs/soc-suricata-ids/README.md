# soc-suricata-ids — Suricata IDS Rule Fundamentals

Use Suricata EVE JSON to practice alert triage, custom signature thinking, and rule-to-event mapping for DMZ traffic.

## Build And Deploy

```bash
docker build -t soc-endpoint:local images/soc-endpoint/
docker build -t soc-sensor:local images/soc-sensor/
docker build -t soc-attacker:local images/soc-attacker/

./scripts/lab.sh deploy soc-suricata-ids
./scripts/lab.sh check soc-suricata-ids
```

## Key Tasks

1. Generate a scan and repeated SSH probes from `attacker`.
2. Parse `/var/log/suricata/eve.json`.
3. Identify alert source, destination, signature, category, and severity.
4. Compare the Suricata alert with Zeek `conn.log` for the same source IP.
5. Draft a threshold or suppression rule that would reduce repeated SSH alert noise.

## Useful Commands

```bash
docker exec clab-soc-suricata-ids-attacker /opt/soc-lab/run-attack-sequence.sh

docker exec clab-soc-suricata-ids-sensor \
  jq -r 'select(.event_type=="alert") |
  [.src_ip,.dest_ip,.dest_port,.alert.signature,.alert.severity] | @tsv' \
  /var/log/suricata/eve.json
```

## Outcome

You can read EVE JSON alert records and map Suricata detections to observed network behavior.
