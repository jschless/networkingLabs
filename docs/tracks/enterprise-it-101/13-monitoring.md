---
title: "13 — Monitoring & Alerting"
---

!!! tip "Operations Lab 1 of 4"
    Deploy Prometheus, Grafana, and Alertmanager to monitor all `lab.corp` services. Build dashboards, write alert rules, and trigger a real alert by stopping a container.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/13-monitoring/`  
**Requires:** Foundation + Labs 05–12

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `prometheus` | `prom/prometheus:latest` | `10.100.3.20` | Metrics collection |
| `grafana` | `grafana/grafana:latest` | `10.100.3.21` | Dashboards |
| `alertmanager` | `prom/alertmanager:latest` | `10.100.3.22` | Alert routing |
| `blackbox` | `prom/blackbox-exporter:latest` | `10.100.3.23` | Endpoint probes |
| `node-exporter` | sidecar on each host | various | Host metrics |

## What is Pre-Built

- Prometheus running with an empty scrape config
- Grafana running with no datasources
- node-exporter sidecar on `dc1`, `mail1`, `keycloak`, `proxy1`
- blackbox-exporter for HTTP/TCP/ICMP/DNS probes

## What You Configure

**1. Configure Prometheus scrape targets**

`prometheus.yml`:
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets:
          - dc1.lab.corp:9100
          - mail1.lab.corp:9100
          - keycloak.lab.corp:9100
          - proxy1.lab.corp:9100

  - job_name: blackbox_tcp
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets:
          - dc1.lab.corp:389    # LDAP
          - dc1.lab.corp:636    # LDAPS
          - dc1.lab.corp:88     # Kerberos
          - mail1.lab.corp:25   # SMTP
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - target_label: __address__
        replacement: blackbox.lab.corp:9115
```

**2. Add Grafana datasource**

Open `http://10.100.3.21:3000` (admin/admin) → Configuration → Data Sources → Add Prometheus at `http://prometheus.lab.corp:9090`.

**3. Build the Lab Corp Overview dashboard**

Create panels for:
- Host health: CPU, memory, disk per node (`node_cpu_seconds_total`, `node_memory_MemFree_bytes`)
- Service availability: `probe_success` per target
- DNS query latency: `probe_dns_lookup_time_seconds`

**4. Configure alert rules**

`alert-rules.yml`:
```yaml
groups:
  - name: lab-corp
    rules:
      - alert: DCDown
        expr: up{job="blackbox_tcp", instance="dc1.lab.corp:389"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Domain controller LDAP is unreachable"

      - alert: DiskUsageHigh
        expr: (1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) > 0.8
        for: 5m
        labels:
          severity: warning

      - alert: TLSCertExpiringSoon
        expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 7
        for: 1h
        labels:
          severity: warning
```

**5. Trigger an alert**

```bash
docker stop dc1
# Wait 1 minute, then check:
curl http://10.100.3.22:9093/api/v2/alerts | jq
```

## Verification Commands

```bash
# Prometheus target health
curl 'http://10.100.3.20:9090/api/v1/targets' \
  | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Query: which services are up?
curl 'http://10.100.3.20:9090/api/v1/query?query=up' | jq

# Active alerts in Alertmanager
curl http://10.100.3.22:9093/api/v2/alerts | jq

# Grafana: browser
# http://10.100.3.21:3000
```

## What This Lab Teaches

- **Monitoring** answers "is it working?" before users report it broken
- **Pull-based model**: Prometheus scrapes targets on a schedule — targets do not push
- **Blackbox probes** test services the way users experience them: "can I connect? does it respond?"
- **Alerting without routing** is useless — Alertmanager routes, deduplicates, and silences
- **Dashboards** are for humans; **alerts** are for incidents — you need both
- **TLS certificate expiry monitoring** prevents the most common avoidable enterprise outage

## Experiments

- Create a recording rule to pre-compute 24-hour service uptime percentage
- Add a Loki instance and ship container logs alongside metrics
- Build a dashboard showing all Kerberos-dependent services with a single-pane-of-glass view
- Configure a PagerDuty-style webhook receiver and test the full alert delivery pipeline
