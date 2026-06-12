---
title: "13 Monitoring & Alerting"
---

!!! tip "Practice Lab"
    Wire Prometheus, node-exporter sidecars, blackbox probes, Grafana, and Alertmanager around the real lab.corp services: scrape configs, PromQL, alert rules, and a webhook "pager" — then kill the DC to trigger an alert storm, and kill the prober to learn why "no alert" and "all clear" aren't the same statement

!!! note "Platform"
    Docker Compose — `prom/prometheus`, `grafana/grafana`, `prom/alertmanager`, `prom/blackbox-exporter`, `prom/node-exporter` + custom `samba-ad:local` / `workstation:local`

{%
  include-markdown "../../../enterprise-it-101/labs/13-monitoring/README.md"
%}
