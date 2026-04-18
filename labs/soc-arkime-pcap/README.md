# soc-arkime-pcap — Packet Search And Evidence

Practice full-packet workflow concepts: session search, PCAP export, and packet evidence tied back to Zeek and Suricata records.

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
