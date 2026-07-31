# soc-ir-case-management — End-To-End Incident Response

Tie the SOC layers together into an incident workflow: alert triage, Zeek context, packet evidence, observables, case tasks, and timeline output.


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

./scripts/lab.sh deploy soc-ir-case-management
./scripts/lab.sh check soc-ir-case-management
```

## Key Tasks

1. Generate the attack sequence from `attacker`.
2. Review Suricata alerts and Zeek logs on `sensor`.
3. Review `/var/lib/thehive/case.json` on `case-mgmt`.
4. Add source IP, destination IP, and file rule as case observables.
5. Produce a short timeline from `/var/log/soc/incident-timeline.md`.

## Useful Commands

```bash
./scripts/lab.sh cmd soc-ir-case-management attacker -- /opt/soc-lab/run-attack-sequence.sh
./scripts/lab.sh cmd soc-ir-case-management case-mgmt -- jq . /var/lib/thehive/case.json
./scripts/lab.sh cmd soc-ir-case-management sensor -- cat /var/log/soc/incident-timeline.md
```

## Outcome

You can work an incident from detection through evidence gathering and case documentation.

## Challenge questions

No answers provided — reason them through.

1. Good IR is reproducible. Walk through the chain of custody and timeline you'd build from this lab's evidence so a second analyst reaches the same conclusion independently.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
