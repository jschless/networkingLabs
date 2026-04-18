# soc-adversary-simulation — ATT&CK-Style Detection Coverage

Run a contained adversary simulation against DMZ services and record coverage. The lab maps local traffic patterns to ATT&CK-style techniques without using live targets.

## Build And Deploy

```bash
docker build -t soc-endpoint:local images/soc-endpoint/
docker build -t soc-sensor:local images/soc-sensor/
docker build -t soc-attacker:local images/soc-attacker/

./scripts/lab.sh deploy soc-adversary-simulation
./scripts/lab.sh check soc-adversary-simulation
```

## Key Tasks

1. Run `/opt/soc-lab/run-attack-sequence.sh` on `attacker`.
2. Review `/var/log/soc/detection-matrix.json` on `sensor`.
3. Map T1046, T1595, and T1110 to available detections.
4. Identify one detection gap you would close with a Suricata rule or Zeek script.
5. Re-run the check after updating the matrix or detection artifact.

## Useful Commands

```bash
docker exec clab-soc-adversary-simulation-attacker /opt/soc-lab/run-attack-sequence.sh
docker exec clab-soc-adversary-simulation-sensor jq . /var/log/soc/detection-matrix.json
```

## Outcome

You produce a coverage matrix that ties adversary behavior to concrete detection sources.
