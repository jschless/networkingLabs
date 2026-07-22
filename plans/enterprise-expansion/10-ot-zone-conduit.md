# WP-10 — OT/IoT Zone-and-Conduit Networking

## Outcome

Build `labs/ot-zone-conduit/`, a practice lab that connects enterprise IT to a
small industrial/cyber-physical environment through an industrial DMZ and explicit
conduits. It should teach availability/safety-aware segmentation, jump-host remote
maintenance, historian flow, industrial protocol visibility, and diagnosis of a
stale-data incident without encouraging unsafe offensive behavior.

Target coverage: level 4.

## Scope and safety boundary

Live:

- Purdue-inspired enterprise, IDMZ, site operations and cell/area zones;
- routed/firewalled conduits with default deny;
- Modbus/TCP or another simple open industrial protocol using lab-only simulator data;
- HMI read, tightly controlled engineering write, historian export, and remote
  maintenance through a jump host;
- passive IDS/Zeek/Suricata visibility and protocol-aware alerting where supported;
- asymmetric policy and stateful return-path failure;
- logging/time dependency and evidence preservation.

Evidence/concept:

- safety instrumented systems, deterministic fieldbuses, real PLC programming,
  vendor engineering stations, TSN hardware, physical process hazards, and plant
  change-control procedures.

The lab must never provide instructions for attacking real industrial systems.
All addresses, device IDs, process values, and credentials are unmistakably synthetic.

## Feature-probe gate

1. Pin a maintained Modbus/TCP simulator/client library and prove deterministic
   register reads/writes with a documented fake process.
2. Prove nftables or selected firewall enforces stateful zone policy and logs rule IDs.
3. Prove Suricata/Zeek parses or at least identifies the selected protocol and emits
   the planned alerts. If deep parsing is absent, use exact flow/function evidence
   from the application logs and do not claim DPI.
4. Prove packet mirroring/capture sees the industrial flow without being inline.
5. Prove all simulator state resets on redeploy.

## Lab type and platform

- Type: practice.
- `enterprise-rtr`, `site-rtr`: cEOS if useful for routing/VRF.
- `idmz-fw`: Linux nftables or existing firewall image with deterministic CLI.
- `jump`, `historian`, `ids`, `hmi`, `eng-ws`, `plc1`, `plc2`, `attacker-test`:
  pinned Linux images.
- Reuse SOC sensor patterns and time/log infrastructure rather than creating a
  second incompatible telemetry stack.

## Topology/addressing

```text
 enterprise-user -- enterprise-rtr -- idmz-fw -- jump / historian
                                      |
                                   site-rtr
                                      |
                                  cell-switch
                               hmi / eng-ws / plc1 / plc2
                                      |
                                  passive IDS
```

| Zone | Prefix | Purpose |
|---|---|---|
| Enterprise | `10.110.10.0/24` | Business/user network |
| IDMZ | `10.110.20.0/24` | Jump, historian relay, update staging |
| Site operations | `10.110.30.0/24` | OT management |
| Cell/area | `10.110.40.0/24` | HMI/PLCs |
| Safety fixture | `10.110.50.0/24` | Evidence-only isolated zone, no live writes |

Prebuild routes, fake process, simulator services, clocks/log collection, and passive
sensor. Withhold zone firewall policy, jump workflow, historian flow, management
authorization and IDS rules.

## Student task sequence

1. **Guided asset/flow inventory:** identify zones, owners, criticality and required
   flows from a supplied communication matrix. Reject broad “any/any” requirements.
2. **Hinted conduits:** implement enterprise→IDMZ, IDMZ→site and site→cell rules with
   explicit direction/port/source, state handling and logging. Prove default deny.
3. **Hinted operations:** permit HMI reads and historian collection; deny enterprise
   direct-to-PLC and unauthorized engineering writes.
4. **Hinted remote maintenance:** require enterprise user → jump host → engineering
   endpoint, with separate authentication/logging and a time-bounded maintenance rule.
5. **Hinted monitoring:** mirror cell traffic, identify protocol/function activity,
   alert on unauthorized write attempts, and correlate firewall/IDS/application time.
6. **Open change case:** introduce a new sensor gateway and update the flow matrix,
   policy, monitoring and rollback plan without flattening zones.
7. **Break-It:** historian data goes stale while HMI reads remain current. The cause
   is an IDMZ return-path/policy change, not a PLC failure. Diagnose from last-good
   timestamps, captures and firewall counters, repair the intended conduit, and prove
   unauthorized enterprise access remains denied.
8. **Safety evidence case:** interpret supplied maintenance window, safety-zone
   boundary, fail-safe behavior and recovery checklist; explain why a technically
   valid network fix may still require process-owner authorization.

## Make the invisible visible

- Decode lab Modbus function/register flows and map them to fake process values.
- Display rule IDs/counters on each conduit.
- Correlate HMI, historian, IDS and firewall timestamps.
- Compare passive monitoring with inline enforcement.
- Show negative-path evidence for direct enterprise access and unauthorized writes.

## Automated checks

`check.sh` must assert at minimum:

1. HMI reads approved PLC registers.
2. Historian receives periodic data.
3. Authorized engineering write works only during enabled maintenance policy.
4. Enterprise user cannot reach PLC directly.
5. Unauthorized writes fail and generate an alert.
6. Jump host can reach only approved management endpoints/ports.
7. PLCs cannot initiate into enterprise.
8. IDS receives mirrored traffic but is not a forwarding dependency.
9. Zone clocks/logs are within the lab correlation bound.
10. Historian stale-data Break-It fails while HMI health remains green.
11. Static route/host-file workarounds do not satisfy policy/counter assertions.

## Planned files/docs

- Standard lab files, simulator definitions, communication matrix, maintenance
  request template, IDS rules, `PROBE.md`, and `VALIDATION.md`.
- New `docs/tracks/ot-iot/index.md` and wrapper, with NIST/ISA-oriented reading links
  but vendor-neutral live tasks.
- Fixture provenance for safety/process artifacts.

## Resource target

- Up to 2 cEOS + 9 lightweight Linux; target ≤ 6 GiB steady.

## Definition of done

All master gates apply. Validate every communication-matrix permit and deny,
maintenance expiry, historian cadence, passive IDS independence, stale-data Break-It,
and clean fake-process reset. A security/OT reviewer should review terminology and
safety framing before merge.
