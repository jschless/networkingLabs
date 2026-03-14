# Network Operations Track

Four labs covering observability (SNMP, syslog, SPAN, NetFlow), QoS, network automation with NetBox, and streaming telemetry.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [network-assurance](network-assurance.md) | Practice | SNMP, syslog, SPAN, NetFlow — four observability mechanisms |
| [qos-enterprise](qos-enterprise.md) | Practice | Linux `tc` QoS: DSCP marking, HTB scheduling, WRED, SFQ |
| [network-automation-netbox](network-automation-netbox.md) | Practice | NetBox inventory, automation workflow, programmatic config |
| [telemetry-monitoring-hybrid](telemetry-monitoring-hybrid.md) | Practice | gNMI telemetry, Prometheus, Grafana, classic NMS |

## Platform Notes

- **network-assurance**: `docker build -t assurance-lab:local labs/network-assurance/`
- **qos-enterprise**: `docker build -t qos-lab:local labs/qos-enterprise/`
- **network-automation-netbox / telemetry**: `docker build -t frr-lab:local images/frr/`
