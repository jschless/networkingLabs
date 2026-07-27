# Network Operations Track

Sixteen labs covering management access, DHCP/DNS, AAA operations, packet capture workflow, hybrid-flow evidence, carrier acceptance, MTU/PMTUD troubleshooting, observability (SNMP, syslog, SPAN, NetFlow), QoS, zero-touch provisioning, API-driven automation fundamentals, network automation with NetBox, and streaming telemetry.

The Enterprise track's
[enterprise-voice-sip-qos](../enterprise/enterprise-voice-sip-qos.md) lab
extends the QoS practice into live SIP/RTP, stateful media NAT, and
one-way-audio troubleshooting. It is registered and counted in Enterprise only.

| Lab | Type | What You Learn |
|-----|------|----------------|
| [management-access-control](management-access-control.md) | Practice | Restrict SSH/UI access by source subnet and interface, verify with counters |
| [dhcp-dns-troubleshooting](dhcp-dns-troubleshooting.md) | Practice | Diagnose DHCP option issues and DNS correctness from the client side |
| [aaa-ops-troubleshooting](aaa-ops-troubleshooting.md) | Practice | TACACS reachability, shared secrets, local fallback, break-glass access |
| [ipv6-access-services](ipv6-access-services.md) | Practice | Router advertisements, SLAAC, default route learning, DNS over IPv6 |
| [enterprise-dual-stack-capstone](enterprise-dual-stack-capstone.md) | Cross-track capstone | IPv4/IPv6 control/data path parity, DNS, PMTUD, and return-path diagnosis |
| [packet-analysis-basics](packet-analysis-basics.md) | Practice | ARP, OSPF, ICMP, TCP handshake capture, mirrored traffic, Wireshark workflow |
| [mtu-pmtud-troubleshooting](mtu-pmtud-troubleshooting.md) | Practice | GRE overhead, exact-size probes, PMTUD, tunnel MTU correction |
| [network-assurance](network-assurance.md) | Practice | SNMP, syslog, SPAN, NetFlow — four observability mechanisms |
| [qos-enterprise](qos-enterprise.md) | Practice | Linux `tc` QoS: DSCP marking, HTB scheduling, WRED, SFQ |
| [ztp-basics](ztp-basics.md) | Practice | Zero-touch provisioning: DHCP option 67 + HTTP config service, factory-reset a cEOS and watch native ZTP install your config |
| [automation-fundamentals](automation-fundamentals.md) | Practice | eAPI from curl up to Python: structured state, idempotent change, verify-from-the-other-end, drift report |
| [network-automation-netbox](network-automation-netbox.md) | Practice | NetBox capstone: DCIM, IPAM, native config templates, discovery sync, and drift validation |
| [suzieq-network-observability](suzieq-network-observability.md) | Reference | SuzieQ: agentless polling, fleet-wide queries, LLDP topology mapping, path tracing, health assertions |
| [telemetry-monitoring-hybrid](telemetry-monitoring-hybrid.md) | Practice | gNMI telemetry, Prometheus, Grafana, classic NMS |
| [cloud-hybrid-networking](cloud-hybrid-networking.md) | Practice | Route-table, conntrack, DNS-view, and capture evidence for a hybrid outage |
| [carrier-ethernet-handoff](carrier-ethernet-handoff.md) | Practice | Demarc capture, MTU/SLA acceptance, evidence packet, and wrong S-VLAN diagnosis |

## Platform Notes

- **management-access-control**: `docker build -t ops-lab:local images/ops-lab/`
- **dhcp-dns-troubleshooting**: `docker build -t ops-lab:local images/ops-lab/` and `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- **aaa-ops-troubleshooting**: `docker build -t ops-lab:local images/ops-lab/`, `docker build -f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/`, and `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- **ipv6-access-services**: `docker build -t ops-lab:local images/ops-lab/`
- **network-assurance**: `docker build -t assurance-lab:local labs/network-assurance/`
- **qos-enterprise**: `docker build -t qos-lab:local labs/qos-enterprise/`
- **ztp-basics**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F` and `docker build -t ops-lab:local images/ops-lab/`
- **automation-fundamentals**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F` and `docker build -t automation-fundamentals:local labs/automation-fundamentals/`
- **network-automation-netbox**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F` and `docker build -t netbox-automation:local labs/network-automation-netbox/`
- **suzieq-network-observability**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F` and `docker build -t suzieq-lab:local labs/suzieq-network-observability/`
- **telemetry-monitoring-hybrid**: `docker build -t telemetry-lab:local labs/telemetry-monitoring-hybrid/`
- **cloud-hybrid-networking**: `docker build -t cloud-lab:local labs/cloud-hybrid-networking/` and import cEOS 4.35.2F
