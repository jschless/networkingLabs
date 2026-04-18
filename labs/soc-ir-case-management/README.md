# soc-ir-case-management — End-To-End Incident Response

Tie the SOC layers together into an incident workflow: alert triage, Zeek context, packet evidence, observables, case tasks, and timeline output.

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
docker exec clab-soc-ir-case-management-attacker /opt/soc-lab/run-attack-sequence.sh
docker exec clab-soc-ir-case-management-case-mgmt jq . /var/lib/thehive/case.json
docker exec clab-soc-ir-case-management-sensor cat /var/log/soc/incident-timeline.md
```

## Outcome

You can work an incident from detection through evidence gathering and case documentation.
