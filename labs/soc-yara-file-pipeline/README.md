# soc-yara-file-pipeline — YARA File Analysis Pipeline

Build the file-analysis side of the SOC stack: Zeek-style file extraction feeding YARA-style file matches. The lab uses a harmless extracted text file instead of malware.


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

./scripts/lab.sh deploy soc-yara-file-pipeline
./scripts/lab.sh check soc-yara-file-pipeline
```

## Key Tasks

1. Fetch `/downloads/readme.txt` from `dmz-web`.
2. Inspect `/extract_files/readme.txt` on the sensor.
3. Read `/var/log/yara/hits.json` and identify the matching rule.
4. Write a local YARA rule for `SOC_LAB_TEST_FILE` and run it against `/extract_files`.
5. Decide what fields should be forwarded to a SIEM.

## Useful Commands

```bash
./scripts/lab.sh cmd soc-yara-file-pipeline attacker -- \
  curl -s http://172.16.10.10/downloads/readme.txt

./scripts/lab.sh cmd soc-yara-file-pipeline sensor -- \
  jq . /var/log/yara/hits.json
```

## Outcome

You have a benign file extraction and YARA hit workflow that can be ingested alongside Zeek and Suricata telemetry.

## Challenge questions

No answers provided — reason them through.

1. YARA matches file *content* patterns. Give a malware variant that evades a naive string rule and the rule-writing technique (conditions, hex, imports) that catches it anyway.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
