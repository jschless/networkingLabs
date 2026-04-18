# soc-threat-intel-misp — IOC Operationalization

Model a threat-intel pipeline from IOC storage to Suricata rule export. The lab uses local MISP-style artifacts so the workflow is reproducible without an internet feed.

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
docker exec clab-soc-threat-intel-misp-misp jq . /var/lib/misp/iocs.json
docker exec clab-soc-threat-intel-misp-misp cat /etc/suricata/rules/misp-generated.rules
```

## Outcome

You understand the operational chain from threat intel to detection content to analyst alert.
