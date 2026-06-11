# soc-zeek-analysis — Zeek Protocol Analysis

Use the shared DMZ topology to study Zeek-style protocol logs and behavioral notices. This lab provides deterministic JSON logs so the analysis workflow is usable even before replacing the artifact generator with a full Zeek runtime.


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

./scripts/lab.sh deploy soc-zeek-analysis
./scripts/lab.sh check soc-zeek-analysis
```

## Key Tasks

1. Generate HTTP, API, scan, and SSH probe traffic from `attacker`.
2. Inspect `/var/log/zeek/conn.log` for source, destination, port, service, and connection state.
3. Inspect `/var/log/zeek/http.log` for URI, host, status code, and user-agent.
4. Read `/var/log/zeek/notice.log` and identify the scan behavior.
5. Use `jq` filters to answer analyst questions.

## Useful Commands

```bash
docker exec clab-soc-zeek-analysis-attacker /opt/soc-lab/run-attack-sequence.sh

docker exec clab-soc-zeek-analysis-sensor \
  jq -r '"\(.["id.orig_h"]) -> \(.["id.resp_h"]):\(.["id.resp_p"]) \(.service)"' \
  /var/log/zeek/conn.log

docker exec clab-soc-zeek-analysis-sensor \
  jq -r '.uri' /var/log/zeek/http.log
```

## Outcome

You can use Zeek connection, HTTP, and notice records to explain what happened on the DMZ wire without reading raw packets first.

## Challenge questions

No answers provided — reason them through.

1. Zeek gives you protocol *metadata* (conn/http/notice), not raw packets. Name one investigation it solves faster than packet analysis, and one question it cannot answer without the PCAP.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
