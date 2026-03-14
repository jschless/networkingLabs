# telemetry-monitoring-hybrid — SNMP and gNMI Monitoring Lab

This lab gives you a realistic, prebuilt monitoring environment without making you configure the tools yourself.

You get two deployment profiles over the same small mixed enterprise/SP network:

- `lite`: `gNMIc + Prometheus + Grafana`
- `full`: `OpenNMS Horizon + PostgreSQL + gNMIc + Prometheus + Grafana`

The network is intentionally laptop-friendly:
- 4 FRR/Linux routers
- 1 cEOS router for native gNMI
- 2 Linux endpoints

Use the `lite` profile by default on a constrained laptop. `full` adds OpenNMS and PostgreSQL and needs materially more RAM and startup time.
Run only one profile at a time. They reuse the same node addressing and are meant to be alternative views of the same lab, not concurrent deployments.

## What this lab teaches

- What a classic NMS sees with **SNMP polling**
- What a modern collector sees with **streaming gNMI telemetry**
- How availability/alarm tooling differs from metrics/dashboard tooling
- What a small NOC view looks like across enterprise, provider, and data-center segments

## Topology

```text
[client]
   |
[branch1 - FRR] --- [campus1 - cEOS] --- [pe1 - FRR] --- [core1 - FRR] --- [dc1 - FRR] --- [server]
```

Roles:
- `branch1`: enterprise branch edge
- `campus1`: campus/distribution router and native gNMI target
- `pe1`: provider edge
- `core1`: provider/core transit
- `dc1`: data-center edge

## Build

```bash
docker build -t telemetry-lab:local labs/telemetry-monitoring-hybrid/
```

## Deploy

Lite profile:

```bash
sudo containerlab deploy -t labs/telemetry-monitoring-hybrid/topology-lite.clab.yml
```

Full profile:

```bash
sudo containerlab deploy -t labs/telemetry-monitoring-hybrid/topology-full.clab.yml
```

The `full` profile can take a few minutes before OpenNMS is actually usable in the browser.

## Access

Lite profile:
- Grafana: `http://172.31.30.33:3000` (`admin` / `admin`)
- Prometheus: `http://172.31.30.32:9090`
- Host-local Grafana: `http://127.0.0.1:3000`
- Host-local Prometheus: `http://127.0.0.1:9090`

Full profile adds:
- OpenNMS Horizon: `http://172.31.30.42:8980/opennms` (`admin` / `admin`)
- Host-local OpenNMS: `http://127.0.0.1:8980/opennms`

## Access From Your Laptop

If you SSH to the lab host from your laptop, forward the host-local ports and open them in your laptop browser:

```bash
ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 -L 8980:127.0.0.1:8980 joe@LAB_HOST
```

Then browse to:
- Grafana: `http://127.0.0.1:3000`
- Prometheus: `http://127.0.0.1:9090`
- OpenNMS: `http://127.0.0.1:8980/opennms`

These ports are bound only to the lab host loopback, not all host interfaces.

## What is preconfigured

On the network:
- End-to-end IP reachability via OSPF
- SNMP on all routed network nodes
- cEOS `campus1` configured for gNMI
- `iperf3` server running on `server`

On the monitoring stack:
- `gnmic` subscribing to `campus1` interface counters
- Prometheus scraping `gnmic`
- Grafana provisioning a telemetry dashboard
- OpenNMS full profile auto-importing all network nodes into a requisition

## Exploration path

### 1. Baseline monitoring views

Check the network is up:

```bash
docker exec clab-telemetry-monitoring-lite-client ping -c3 10.20.20.11
```

Or for full profile:

```bash
docker exec clab-telemetry-monitoring-full-client ping -c3 10.20.20.11
```

In Grafana, open `Telemetry Overview`.

In OpenNMS full profile:
- look at node list
- confirm the 5 routed nodes are provisioned
- inspect node outages or interface status

### 2. Generate traffic

Lite:

```bash
docker exec clab-telemetry-monitoring-lite-client iperf3 -c 10.20.20.11 -t 30
```

Full:

```bash
docker exec clab-telemetry-monitoring-full-client iperf3 -c 10.20.20.11 -t 30
```

Expected:
- Grafana interface throughput rises on `campus1`
- OpenNMS interface counters increase on the SNMP-polled nodes

### 3. Explore SNMP directly

Lite:

```bash
docker exec clab-telemetry-monitoring-lite-branch1 snmpwalk -v2c -c public 172.31.30.12 1.3.6.1.2.1.2.2
```

Full:

```bash
docker exec clab-telemetry-monitoring-full-branch1 snmpwalk -v2c -c public 172.31.30.12 1.3.6.1.2.1.2.2
```

### 4. Failure drill

Bring down the `campus1` to `pe1` link.

Lite:

```bash
docker exec clab-telemetry-monitoring-lite-campus1 bash -lc "printf 'enable\nconfigure\ninterface Ethernet2\nshutdown\nend\n' | Cli"
```

Full:

```bash
docker exec clab-telemetry-monitoring-full-campus1 bash -lc "printf 'enable\nconfigure\ninterface Ethernet2\nshutdown\nend\n' | Cli"
```

Expected:
- Grafana streaming counters stop changing for the affected interface
- OpenNMS full profile eventually reports an outage / degraded state

Restore it:

```bash
docker exec clab-telemetry-monitoring-full-campus1 bash -lc "printf 'enable\nconfigure\ninterface Ethernet2\nno shutdown\nend\n' | Cli"
```

Adjust the container name to `...-lite-campus1` if using the lite profile.

## Useful direct commands

gNMI collector metrics:

```bash
curl -s http://172.31.30.31:9804/metrics | head
```

Prometheus targets:

```bash
curl -s http://172.31.30.32:9090/api/v1/targets | jq
```

OpenNMS requisition import logs:

```bash
docker logs clab-telemetry-monitoring-full-opennms-bootstrap
```

## Cleanup

Lite:

```bash
sudo containerlab destroy -t labs/telemetry-monitoring-hybrid/topology-lite.clab.yml --cleanup
```

Full:

```bash
sudo containerlab destroy -t labs/telemetry-monitoring-hybrid/topology-full.clab.yml --cleanup
```
