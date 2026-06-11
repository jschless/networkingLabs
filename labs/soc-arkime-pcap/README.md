# soc-arkime-pcap — Packet Search And Evidence

Practice full-packet workflow concepts: session search, PCAP export, and packet evidence tied back to Zeek and Suricata records.


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

./scripts/lab.sh deploy soc-arkime-pcap
./scripts/lab.sh check soc-arkime-pcap
```

## Key Tasks

1. Review `/var/lib/arkime/sessions.json` on `arkime`.
2. Match the session source/destination pair to Zeek `conn.log`.
3. Locate the referenced PCAP path on `sensor`.
4. Capture fresh mirrored traffic with `tcpdump` or `tshark`.
5. Explain when a packet search tool is more useful than SIEM logs.

## Useful Commands

```bash
docker exec clab-soc-arkime-pcap-arkime jq . /var/lib/arkime/sessions.json
docker exec clab-soc-arkime-pcap-sensor tcpdump -ni eth1 -c 20
```

## Outcome

You can pivot from a session or alert record to packet evidence and reason about packet-retention tradeoffs.

## Challenge questions

No answers provided — reason them through.

1. Full-packet capture is expensive to store. Explain the retention/sampling tradeoff and what investigation becomes impossible once a flow ages out of the PCAP store.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
