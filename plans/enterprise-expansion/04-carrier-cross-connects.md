# WP-04 — Carrier Ethernet, Physical, and Legacy Cross-Connects

## Outcome

Deliver two coordinated artifacts:

1. `labs/carrier-ethernet-handoff/` — a live practice lab for enterprise circuit
   turn-up, QinQ/E-Line behavior, demarc testing, Ethernet OAM where supported,
   MTU/SLA acceptance, and escalation evidence.
2. `labs/fixtures/carrier-cross-connects/` — a provenance-controlled evidence pack
   for fiber/optics, patching, LOA/CFA, legacy TDM/SONET/SDH boundaries, and faults
   that ContainerLab cannot reproduce honestly.

Target: level 4 for packet-Ethernet handoff operations and level 1 for physical and
legacy media.

## Fidelity

Live:

- enterprise CE to provider NID/UNI handoff;
- customer VLAN to provider S-VLAN mapping (QinQ);
- point-to-point E-Line service behavior;
- L2/L3 MTU and throughput acceptance;
- VLAN rewrite/preservation, PCP, and packet capture;
- continuity/loopback/linktrace if supported by cEOS or Open vSwitch;
- service loop, wrong cross-connect, wrong S-VLAN, and one-way policy symptoms;
- turn-up worksheet and provider escalation evidence.

Evidence-only:

- DOM optical Tx/Rx power, thresholds, FEC, BER, connector cleanliness and polarity;
- fiber loss-budget calculation and patch-panel mapping;
- LOA/CFA and meet-me-room workflow;
- T1/E1/DS3, PPP/HDLC, Frame Relay/ATM, SONET/SDH, OTN/DWDM, and circuit-emulation
  boundaries;
- physical loopback plugs, OTDR/spectrum traces, hardware environmental alarms.

Link the existing MPLS L2VPN lab as the live pseudowire follow-on; do not duplicate it.

## Feature-probe gate

Probe cEOS 4.35.2F for:

1. dot1q-tunnel/QinQ encapsulation and expected tag preservation;
2. Ethernet CFM commands, CCM/LBM/LTM support, counters, and cEOS data-plane behavior;
3. per-port MTU and PCP handling;
4. deterministic packet capture of outer and inner tags.

If cEOS CFM is unavailable, probe Open vSwitch CFM. It is acceptable to use OVS
for provider NIDs because the learning objective is standards behavior, but record
the platform choice. If neither produces reliable live CFM, retain CFM/Y.1731 as a
checked packet/show-output evidence exercise and do not invent counters.

## Lab type and platform

- Type: practice with an open turn-up case.
- `ce-a`, `ce-b`: cEOS enterprise edge switches/routers.
- `nid-a`, `p-core`, `nid-b`: cEOS if probe passes; otherwise pinned OVS/Linux image.
- `tester-a`, `tester-b`: Linux with `iperf3`, `tcpdump`, `scapy`, `ethtool`, and
  deterministic MTU/latency/loss test scripts.
- Optional `provider-nms`: lightweight collector for OAM/acceptance results.

## Topology and addressing

```text
 tester-a -- ce-a -- nid-a === p-core === nid-b -- ce-b -- tester-b
                       \----- provider OAM -----/
```

- Customer VLANs: 110 and 120.
- Provider S-VLANs: 3100 and 3120.
- Routed acceptance subnets: `192.0.2.0/30` and `198.51.100.0/30`.
- Provider management/OAM: `10.70.0.0/24` and sequential `/30` transit links.
- Service MTU target: explicitly choose 1600 or 2000 to allow double tagging and
  teach payload/frame-size accounting; record exact interface behavior.

Prebuild management and test endpoints. Withhold UNI service mapping, S-VLAN
cross-connect, OAM endpoints, PCP policy, and acceptance results.

## Student task sequence

1. **Guided order review:** inspect a synthetic service order, LOA/CFA, circuit ID,
   UNI mode, VLAN map, handoff speed/duplex, MTU and SLA. Identify missing or
   contradictory fields before configuration.
2. **Hinted UNI and QinQ:** configure CE/NID handoffs and S-VLAN transport for two
   customer VLANs. Capture and explain inner/outer tags at UNI and provider core.
3. **Hinted OAM:** configure MEPs/maintenance domain and prove continuity,
   loopback, and linktrace if live support exists; otherwise analyze the checked fixture.
4. **Hinted circuit acceptance:** validate link state, negotiation, VLAN mapping,
   exact MTU, bidirectional throughput, loss, latency, jitter, and routed return path.
   Produce a signed-style acceptance report from measured data.
5. **Hinted QoS marking:** preserve or rewrite PCP according to the service order;
   verify by capture under offered load.
6. **Open provider escalation:** given intermittent loss, assemble the minimal
   evidence packet that establishes side of demarc, affected service, time window,
   direction, frame size, and OAM result without prescribing the provider's fix.
7. **Break-It:** NID-B maps customer VLAN 120 into S-VLAN 3100 instead of 3120.
   Link state, OAM domain for VLAN 110, and VLAN 110 service remain healthy; only
   VLAN 120 is delivered to the wrong cross-connect. Diagnose by tag capture and
   service map, repair the mapping, and rerun the acceptance suite.
8. **Physical/legacy evidence case:** calculate an optical budget from supplied
   Tx/Rx/patch data, locate a wrong patch-panel cross-connect, distinguish dirty
   fiber from polarity and unsupported optic evidence, then map a legacy TDM circuit
   to the modern NID/pseudowire boundary.

## Make the invisible visible

- Capture tags before encapsulation, inside the provider, and after decapsulation.
- Show exact frame-size overhead and correlate it with payload tests.
- Show OAM MEP/MIP state or analyze actual-format checked fixtures.
- Require a demarc diagram and evidence timeline.

## Automated checks

`check.sh` must assert at minimum:

1. Correct inner/outer tag mapping for both services.
2. VLAN 110 and 120 remain isolated.
3. Bidirectional endpoint reachability per service.
4. Exact service MTU passes; one byte above the committed payload fails or fragments
   according to documented behavior.
5. Throughput/loss test meets deterministic lab thresholds.
6. OAM continuity is green when live support exists.
7. PCP behavior matches the order.
8. Provider management is unreachable from customer data VLANs.
9. Wrong S-VLAN Break-It fails only the intended service and fails the mapping assertion.
10. Clean destroy leaves no OVS bridge/tap/namespace artifacts.

Evidence exercises need a separate answer validator for calculated budget, selected
fault, cross-connect mapping, and escalation fields.

## Fixture provenance

Use repo-created or freely redistributable artifacts. Include sanitized service
orders, patch sheets, CLI outputs, DOM tables, FEC/BER samples, captures, and
diagrams. Every file needs source/provenance, license, synthetic/live label, expected
answer, and checksum. Never include a real carrier circuit ID, address, customer, or LOA.

## Planned files and docs

- Standard live lab files plus `acceptance.sh`, report template, `PROBE.md`, and
  `VALIDATION.md`.
- Fixture directory and manifest under `labs/fixtures/`.
- `docs/tracks/enterprise/carrier-ethernet-handoff.md`; register also in Operations
  and MPLS/SP study paths without double-counting the same lab.
- Enterprise-wide coverage entries for physical/optical/legacy must remain level 1.

## Resource target

- Up to 5 cEOS/OVS network nodes + 2 Linux testers.
- Prefer ≤ 6 GiB steady; hard ceiling 9 GiB.

## Definition of done

All master gates apply. The turn-up report must be generated from live measurements;
both VLAN mappings and negative isolation are tested; the Break-It is diagnosed from
tags rather than source config; every physical/legacy artifact is provenance-reviewed;
and the docs state exactly which OAM functions were live versus evidence-only.
