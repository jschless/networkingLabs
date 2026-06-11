# soc-kibana-hvt-dashboard — DMZ HVT Monitoring

Design the dashboard layer for high-value DMZ targets. The lab provides saved-object-style dashboard artifacts for traffic, alerts, and file hits.


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

./scripts/lab.sh deploy soc-kibana-hvt-dashboard
./scripts/lab.sh check soc-kibana-hvt-dashboard
```

## Key Tasks

1. Read `/var/lib/soc-siem/hvt-dashboard.ndjson`.
2. Identify panels for Suricata severity, Zeek top sources, and YARA file hits.
3. Define a filter for the DMZ HVTs `172.16.10.10` and `172.16.20.10`.
4. Write KQL-style queries for source IP, destination IP, and alert severity.
5. Confirm dashboard artifacts align with the available indexes.

## Useful Commands

```bash
docker exec clab-soc-kibana-hvt-dashboard-siem \
  grep title /var/lib/soc-siem/hvt-dashboard.ndjson
```

## Outcome

You have a dashboard design that ties Zeek sessions, Suricata alerts, and YARA file hits to the same DMZ targets.

## Challenge questions

No answers provided — reason them through.

1. A dashboard for high-value targets shows green while an attack is underway. List three ways metric choice, time window, or aggregation can hide a real incident on a dashboard.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
