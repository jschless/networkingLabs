# soc-threat-intel-misp — IOC Operationalization

Model a threat-intel pipeline from IOC storage to Suricata rule export. The lab uses local MISP-style artifacts so the workflow is reproducible without an internet feed.


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

./scripts/lab.sh deploy soc-threat-intel-misp
./scripts/lab.sh check soc-threat-intel-misp
```

## Key Tasks

1. Review `/var/lib/misp/iocs.json`.
2. Inspect `/etc/suricata/rules/misp-generated.rules`.
3. Trace an IOC from event attribute to rule message.
4. Decide which IOC types are safe to operationalize directly.
5. Compare this lab workflow with a commercial TIP-to-SIEM pipeline.

## Useful Commands

```bash
./scripts/lab.sh cmd soc-threat-intel-misp misp -- jq . /var/lib/misp/iocs.json
./scripts/lab.sh cmd soc-threat-intel-misp misp -- cat /etc/suricata/rules/misp-generated.rules
```

## Outcome

You understand the operational chain from threat intel to detection content to analyst alert.

## Challenge questions

No answers provided — reason them through.

1. Threat intel indicators (IOCs) decay. Explain why an IP/hash IOC has a short shelf life, the false-positive risk of stale intel, and how you'd score confidence before alerting on a match.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
