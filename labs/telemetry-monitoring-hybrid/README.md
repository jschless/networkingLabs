# telemetry-monitoring-hybrid

This lab is a guided introduction to two different monitoring styles used in real networks:

- a classic NMS workflow built around SNMP polling and inventory, using OpenNMS
- a modern telemetry workflow built around streamed metrics, using gNMIc, Prometheus, and Grafana

The lab is intentionally small enough to run on a laptop, but it is opinionated enough to teach how these tools are actually used.

## What You Are Learning

This lab is not mainly about configuring routers. It is about learning how operators answer questions like:

- What devices do I have?
- Are they up?
- Which interfaces exist on them?
- What changed recently?
- Is traffic rising on a key link?
- Did a link flap, or did traffic simply drop?
- Which tool is best for inventory, polling, alarms, dashboards, and drill-down?

You should come away with a mental model like this:

- OpenNMS is the broad, inventory-and-polling-oriented NMS
- Prometheus is a time-series database and query engine
- Grafana is the visualization layer
- gNMIc is the collector translating streaming telemetry into Prometheus-style metrics

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
- `client`: traffic source
- `server`: traffic sink and `iperf3` server

Design choice:

- most network nodes are FRR/Linux to keep compute usage low
- only `campus1` is cEOS, because it gives a realistic native gNMI telemetry target

## Profiles

There are two deployment profiles over the same network:

- `lite`: `gNMIc + Prometheus + Grafana`
- `full`: `OpenNMS Horizon + PostgreSQL + gNMIc + Prometheus + Grafana`

Use `lite` first if you are tight on RAM. Use `full` when you want the complete comparison between classic polling and streaming telemetry.

Run only one profile at a time. They are alternative views of the same lab.

## Build

```bash
docker build -t telemetry-lab:local labs/telemetry-monitoring-hybrid/
```

## Deploy

Lite:

```bash
sudo containerlab deploy -t labs/telemetry-monitoring-hybrid/topology-lite.clab.yml
```

Full:

```bash
sudo containerlab deploy -t labs/telemetry-monitoring-hybrid/topology-full.clab.yml
```

The full profile needs more time on first boot because OpenNMS must initialize its database and services.

## Access

Direct from the lab host:

- Grafana: `http://127.0.0.1:3000`
- Prometheus: `http://127.0.0.1:9090`
- OpenNMS: `http://127.0.0.1:8980/opennms`

Credentials:

- Grafana: `admin` / `admin`
- OpenNMS: `admin` / `admin`

## Access From Another Machine

If the lab runs on a headless host and you are browsing from your laptop, use SSH local port forwarding:

```bash
ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 -L 8980:127.0.0.1:8980 joe@LAB_HOST
```

Then open on your laptop:

- `http://127.0.0.1:3000`
- `http://127.0.0.1:9090`
- `http://127.0.0.1:8980/opennms`

The lab publishes these services only on the lab host loopback. That is deliberate. SSH forwarding is safer than binding them to the host LAN interface.

## What Is Prebuilt

On the network:

- OSPF end-to-end routing between all routed nodes
- SNMP enabled on the routed nodes
- gNMI enabled on `campus1`
- `iperf3` server running on `server`

On the telemetry stack:

- gNMIc subscribes to `campus1` interface counters
- Prometheus scrapes gNMIc
- Grafana has preprovisioned dashboards:
  - `Telemetry Overview`
  - `Traffic Investigation`
  - `Failure Drill`

On the OpenNMS side in the full profile:

- the five routed nodes are imported automatically into a requisition
- OpenNMS learns basic node identity and SNMP data

Important limitation:

- this lab does not prebuild an OpenNMS topology map workflow
- OpenNMS is useful here for node inventory, availability, interfaces, polling, and classical NMS exploration
- Grafana is the quickest place to see live changing telemetry

That split is intentional and worth learning.

## Scenario Helpers

The lab includes helper scripts in `scripts/` so you can focus on interpretation rather than retyping long commands.

Useful entry points:

- `scripts/scenario-status.sh`
- `scripts/traffic-start.sh 30`
- `scripts/link-down-campus-pe.sh`
- `scripts/link-up-campus-pe.sh`
- `scripts/opennms-summary.sh`
- `scripts/prom-query.sh 'up{job="gnmic"}'`

## Product Walkthrough

### OpenNMS: what it is good at

OpenNMS answers questions like:

- Which nodes exist?
- What are their identities, interfaces, and SNMP properties?
- Are they up or down?
- Which services are being monitored?
- What outages or events have been recorded?

OpenNMS is strongest when you want broad coverage across many devices, even if the data is less immediate than a telemetry stream.

In this lab, think of OpenNMS as:

- the NMS of record
- the inventory and polling engine
- the place to explore nodes, services, outages, and interface state

### Grafana: what it is good at

Grafana answers questions like:

- Is traffic rising right now?
- Which interface saw the change?
- How did a metric behave over the last minute, hour, or day?

Grafana is strongest when you want fast, visual understanding of time-series behavior.

In this lab, think of Grafana as:

- the place where live link behavior is easiest to see
- the consumer of Prometheus metrics
- the quickest feedback loop during experiments

### Prometheus: what it is doing here

Prometheus is not polling the routers directly in this lab. It is scraping gNMIc.

That means the flow is:

1. `campus1` streams telemetry to gNMIc
2. gNMIc exposes those values as Prometheus-format metrics
3. Prometheus scrapes those metrics
4. Grafana queries Prometheus

This is a common pattern in modern telemetry stacks.

### gNMIc: what it is doing here

gNMIc is the telemetry collector and adapter.

In this lab it subscribes to:

- `/interfaces/interface/state/counters/in-octets`
- `/interfaces/interface/state/counters/out-octets`

Those are exported as metrics such as:

- `interfaces_interface_state_counters_in_octets`
- `interfaces_interface_state_counters_out_octets`

The important lesson is that gNMIc is not a dashboard and not a database. It is the bridge between streaming telemetry and the metrics stack.

## Guided Exploration

Start with the full profile if you want to compare both worlds side by side. Use the lite profile if your laptop is tight on resources.

### Exercise 1: establish a baseline

First confirm the network is alive:

Full:

```bash
docker exec clab-telemetry-monitoring-full-client ping -c 3 10.20.20.11
```

Lite:

```bash
docker exec clab-telemetry-monitoring-lite-client ping -c 3 10.20.20.11
```

What this proves:

- the routed path from `client` to `server` is working
- OSPF converged
- the environment is ready for monitoring experiments

Now open:

- Grafana and load `Telemetry Overview`
- Grafana and note that `Traffic Investigation` and `Failure Drill` are also available
- Prometheus and keep the targets page handy
- OpenNMS if you are using the full profile

### Exercise 2: understand what each UI is showing

#### In Grafana

Open `Telemetry Overview`.

You should see:

- `Campus1 Ingress Throughput`
- `Campus1 Egress Throughput`
- `Prometheus -> gNMIc Scrape`

Interpretation:

- the throughput graphs are rates derived from octet counters on `campus1`
- they are filtered to `Ethernet*` interfaces
- the scrape stat tells you whether Prometheus can collect from gNMIc

This is near-real-time telemetry.

#### In Prometheus

Open the expression browser and try:

```promql
up
```

Then:

```promql
interfaces_interface_state_counters_in_octets
```

Then:

```promql
rate(interfaces_interface_state_counters_in_octets{target="campus1",interface_name=~"Ethernet.*"}[1m]) * 8
```

What to notice:

- Prometheus stores samples, not diagrams or device inventory
- the labels on the metrics are how you slice the data
- Grafana is just visualizing the same queries

#### In OpenNMS

Do not expect a fancy topology map on first load.

Instead, use OpenNMS like an operator exploring monitored objects:

1. Go to the node list
2. Find `branch1`, `campus1`, `pe1`, `core1`, and `dc1`
3. Open a node detail page, starting with `campus1`
4. Look for:
   - node identity
   - interfaces
   - SNMP system information
   - service status
   - events or outages

What to notice:

- OpenNMS has a richer concept of a node than Grafana does
- it stores discovery, identity, services, and polling state
- it is better at “what is this thing?” and “is it generally healthy?”

### Exercise 3: generate traffic and compare the products

Run a traffic burst from `client` to `server`.

Full:

```bash
scripts/traffic-start.sh 30
```

Lite:

```bash
scripts/traffic-start.sh 30
```

Now watch the tools.

In Grafana:

- `Telemetry Overview` gives you the baseline quickly
- `Traffic Investigation` is the best dashboard for this drill
- the aggregate and per-interface charts should move clearly

In Prometheus:

- rerun the rate query and inspect the raw values

In OpenNMS:

- look at the relevant node and interface pages
- expect slower, more inventory-oriented updates rather than immediate graph movement

Lesson:

- Grafana/Prometheus excels at showing changing metrics over time
- OpenNMS is not trying to be a low-latency streaming dashboard here

### Exercise 4: query SNMP directly

Use `snmpwalk` to see the sort of raw data classical NMS platforms ingest.

Full:

```bash
docker exec clab-telemetry-monitoring-full-branch1 snmpwalk -v2c -c public 172.31.30.12 1.3.6.1.2.1.2.2
```

Lite:

```bash
docker exec clab-telemetry-monitoring-lite-branch1 snmpwalk -v2c -c public 172.31.30.12 1.3.6.1.2.1.2.2
```

What to notice:

- SNMP exposes device state via MIBs and OIDs
- it is broad and mature
- it is not pleasant to read directly
- an NMS like OpenNMS makes this consumable

This is an important conceptual contrast:

- SNMP is often “wide but old”
- gNMI streaming is often “cleaner and faster, but more targeted”

### Exercise 5: inspect the live telemetry source directly

Check what gNMIc is exporting:

```bash
curl -s http://127.0.0.1:9804/metrics | rg 'interfaces_interface_state_counters'
```

What to notice:

- gNMIc already transformed the streaming updates into metrics
- the labels, such as `interface_name` and `target`, matter a lot
- Prometheus and Grafana depend on stable metric naming

### Exercise 6: create a fault and observe who notices what

Shut the `campus1 -> pe1` link.

Full:

```bash
scripts/link-down-campus-pe.sh
```

Lite:

```bash
scripts/link-down-campus-pe.sh
```

While it is down, check:

- Grafana
- OpenNMS node/interface state
- reachability from `client` to `server`

Ping test:

Full:

```bash
docker exec clab-telemetry-monitoring-full-client ping -c 3 10.20.20.11
```

Lite:

```bash
docker exec clab-telemetry-monitoring-lite-client ping -c 3 10.20.20.11
```

Expected learning:

- Grafana shows the counters stop changing on the affected path
- OpenNMS may take longer, but it should reflect degraded availability or service state
- telemetry is often best for seeing rapid change
- classical NMS is often best for tracking managed objects and durable operational state

Restore the link:

Full:

```bash
scripts/link-up-campus-pe.sh
```

Lite:

```bash
scripts/link-up-campus-pe.sh
```

### Exercise 7: learn the OpenNMS mindset

OpenNMS will make more sense if you use it like this:

1. Start at node inventory, not dashboards
2. Open one node and inspect its discovered interfaces
3. Look at the services attached to those interfaces
4. Check whether outages or events were recorded
5. Use the NMS to answer “what exists?” and “what is down?”

This lab still does not prebuild advanced OpenNMS views such as:

- custom surveillance dashboards
- business-service mapping
- topology presentation layers
- elaborate threshold and alarm policies

That is why Grafana feels more immediately rewarding. The lab is currently stronger at teaching the contrast between polling and streaming than at teaching the full OpenNMS UX.

### Exercise 8: learn the Prometheus mindset

Prometheus becomes useful when you think in terms of:

- metrics
- labels
- queries
- rates

Try these queries:

```promql
up{job="gnmic"}
```

```promql
interfaces_interface_state_counters_in_octets{target="campus1"}
```

```promql
rate(interfaces_interface_state_counters_out_octets{target="campus1",interface_name="Ethernet2"}[1m]) * 8
```

What to notice:

- Prometheus is excellent for deriving meaning from counters
- counter rates are often more useful than the raw counters themselves
- labels are the main navigation mechanism

### Exercise 9: connect the tools mentally

By this point you should be able to map the stack like this:

- Device inventory and node health: OpenNMS
- Raw time-series storage and query engine: Prometheus
- Graphs and operator-facing visualization: Grafana
- Streaming collector and exporter: gNMIc

That is the core lesson of this lab.

## How To Influence The Environment

These are the most useful knobs for experiments.

### Generate more traffic

```bash
docker exec clab-telemetry-monitoring-full-client iperf3 -c 10.20.20.11 -t 60
```

Change `-t` to run longer.

### Verify reachability

```bash
docker exec clab-telemetry-monitoring-full-client ping -c 3 10.20.20.11
```

### Break and restore the key cEOS uplink

Down:

```bash
docker exec clab-telemetry-monitoring-full-campus1 bash -lc "printf 'enable\nconfigure\ninterface Ethernet2\nshutdown\nend\n' | Cli"
```

Up:

```bash
docker exec clab-telemetry-monitoring-full-campus1 bash -lc "printf 'enable\nconfigure\ninterface Ethernet2\nno shutdown\nend\n' | Cli"
```

### Inspect the gNMI collector metrics

```bash
curl -s http://127.0.0.1:9804/metrics | head -n 40
```

### Inspect Prometheus scrape targets

```bash
curl -s http://127.0.0.1:9090/api/v1/targets | jq
```

### Inspect imported OpenNMS nodes

```bash
docker exec clab-telemetry-monitoring-full-opennms-bootstrap \
  sh -lc 'curl -s -u admin:admin "http://172.31.30.42:8980/opennms/rest/nodes?limit=20"'
```

## What To Expect In OpenNMS

If you open OpenNMS and think “I don’t see much,” that is partly normal in this lab.

You should expect:

- imported nodes
- interface and SNMP identity data
- outages and service state after you create failures

You should not expect:

- a polished topology graph on first load
- highly visual streaming charts like Grafana
- instant insight without clicking into nodes and services

That difference is exactly part of the lesson.

## Where To Look First

If you only have 20 minutes, do this:

1. Open Grafana and observe baseline traffic
2. Run `scripts/traffic-start.sh 30` and watch `Traffic Investigation`
3. Open OpenNMS and inspect `campus1`
4. Run `scripts/link-down-campus-pe.sh`
5. Compare what `Failure Drill` shows immediately versus what OpenNMS records over time
6. Run `scripts/link-up-campus-pe.sh`

If you do that carefully, you will understand more about these tools than by just clicking around randomly.

## Cleanup

Lite:

```bash
sudo containerlab destroy -t labs/telemetry-monitoring-hybrid/topology-lite.clab.yml --cleanup
```

Full:

```bash
sudo containerlab destroy -t labs/telemetry-monitoring-hybrid/topology-full.clab.yml --cleanup
```
