# soc-adversary-simulation — ATT&CK-Style Detection Coverage

Run a contained adversary simulation against DMZ services and record coverage. The lab maps local traffic patterns to ATT&CK-style techniques without using live targets.


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
./scripts/lab.sh cmd soc-adversary-simulation attacker -- /opt/soc-lab/run-attack-sequence.sh
./scripts/lab.sh cmd soc-adversary-simulation sensor -- jq . /var/log/soc/detection-matrix.json
```

## Outcome

You produce a coverage matrix that ties adversary behavior to concrete detection sources.

## Challenge questions

No answers provided — reason them through.

1. You're emulating an adversary to test detection. Map your simulated steps to a kill-chain/ATT&CK stage and identify which step *should* have alerted but didn't — that gap is the finding.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
