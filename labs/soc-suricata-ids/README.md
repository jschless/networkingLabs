# soc-suricata-ids — Suricata IDS Rule Fundamentals

Use Suricata EVE JSON to practice alert triage, custom signature thinking, and rule-to-event mapping for DMZ traffic.


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

## Challenge questions

No answers provided — reason them through.

1. Suricata is signature + protocol-anomaly based. Construct an attack a signature catches and one it misses, and explain why IDS alerts must be triaged, not trusted blindly.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
