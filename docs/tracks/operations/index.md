# Network Operations Track

Six labs covering packet capture workflow, MTU/PMTUD troubleshooting, observability (SNMP, syslog, SPAN, NetFlow), QoS, network automation with NetBox, and streaming telemetry.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [packet-analysis-basics](packet-analysis-basics.md) | Practice | ARP, OSPF, ICMP, TCP handshake capture, mirrored traffic, Wireshark workflow |
| [mtu-pmtud-troubleshooting](mtu-pmtud-troubleshooting.md) | Practice | GRE overhead, exact-size probes, PMTUD, tunnel MTU correction |
| [network-assurance](network-assurance.md) | Practice | SNMP, syslog, SPAN, NetFlow — four observability mechanisms |
| [qos-enterprise](qos-enterprise.md) | Practice | Linux `tc` QoS: DSCP marking, HTB scheduling, WRED, SFQ |
| [network-automation-netbox](network-automation-netbox.md) | Practice | NetBox capstone: DCIM, IPAM, native config templates, discovery sync, and drift validation |
| [telemetry-monitoring-hybrid](telemetry-monitoring-hybrid.md) | Practice | gNMI telemetry, Prometheus, Grafana, classic NMS |

## Platform Notes

- **network-assurance**: `docker build -t assurance-lab:local labs/network-assurance/`
- **qos-enterprise**: `docker build -t qos-lab:local labs/qos-enterprise/`
- **network-automation-netbox**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F` and `docker build -t netbox-automation:local labs/network-automation-netbox/`
- **telemetry-monitoring-hybrid**: `docker build -t frr-lab:local images/frr/`
