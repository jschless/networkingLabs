# soc-kibana-hvt-dashboard — DMZ HVT Monitoring

Design the dashboard layer for high-value DMZ targets. The lab provides saved-object-style dashboard artifacts for traffic, alerts, and file hits.

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
