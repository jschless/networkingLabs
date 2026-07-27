# Feature Probe Record — `ot-zone-conduit`

## Scope and decision

- **Feature and learning objective:** prove deterministic synthetic Modbus/TCP
  reads/writes, stateful zone enforcement with visible rule IDs and counters,
  protocol-aware passive detection, non-inline mirroring, and clean simulator reset.
- **Decision:** go.
- **Reason and fidelity statement:** the four-node disposable probe exercised real
  PyModbus transactions through a Linux nftables forward path. `tc mirred` cloned
  the flow to a non-routed Suricata interface; Suricata decoded Modbus function 6
  and emitted the planned alert. NFLOG/ulogd recorded the exact nftables rule IDs.
  Stopping the sensor did not affect the Modbus data path. This supports the
  work-package's Linux fallback directly and makes no PLC, safety-controller,
  deterministic-fieldbus, or industrial-hardware claim.
- **Owner and date:** Codex, 2026-07-27.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b`, 2026-03-15 |
| Docker | client/server `29.5.3` |
| Base image | `ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90` |
| Probe image | `ot-zone-tools:1.0.0`, image ID `sha256:a28c723bef64fd18619ba3573a3995ee18f7a6a24fb93fa1c6ca846b38cbdfe5`, 196,947,312 bytes |
| Components | PyModbus `3.11.3`; Suricata `7.0.3`; nftables `1.0.9`; ulogd `2.0.8`; tcpdump `4.99.4` |
| Host memory before final probe | 15 GiB total, 12 GiB available, 0 B swap used |
| Host filesystem before final probe | 142 GiB available on `/home/joe/containerlab` |

PyModbus is pinned to the verified `3.11.3` release. Suricata 7's documented
`modbus: function <value>` matcher was enabled explicitly because Ubuntu's packaged
configuration disables the Modbus parser by default.

## Smallest load-bearing test

The probe topology is:

```text
client -- stateful nftables fw -- synthetic plc
                         |
                    tc mirror only
                         |
                 passive Suricata sensor
```

Command:

```bash
labs/ot-zone-conduit/probe/probe.sh
```

The script builds the pinned image, deploys
`labs/ot-zone-conduit/probe/topology.clab.yml`, performs an approved read and
single-register write, attempts a connection from an unapproved source address,
checks nftables counters and NFLOG records, checks the Suricata EVE alert, stops
the sensor and reads again, destroys, redeploys, and verifies initial state.

Relevant final-run output:

```text
build elapsed=0.27 max_rss_kib=52928
deploy elapsed=1.38 max_rss_kib=40972
initial={"line_speed_rpm": 420, "tank_level_pct": 73}
after_write={"line_speed_rpm": 420, "tank_level_pct": 88}
unauthorized_source=denied
counter permit_modbus { packets 3 bytes 180 }
counter deny_other { packets 1 bytes 60 }
Jul 27 11:50:27 fw OT-RULE-100 modbus ... SRC=10.250.10.2 DST=10.250.20.2 ... DPT=502 ...
Jul 27 11:50:27 fw OT-RULE-199 default-deny ... SRC=10.250.10.99 DST=10.250.20.2 ... DPT=502 ...
{"event_type":"alert","app_proto":"modbus","signature":"LAB-OT Modbus single-register write observed"}
sensor_stopped_read={"line_speed_rpm": 420, "tank_level_pct": 88}
redeploy elapsed=1.59 max_rss_kib=40860
reset={"line_speed_rpm": 420, "tank_level_pct": 73}
```

Steady per-container memory at the sample point was client 1.0 MiB, firewall
1.1 MiB, PLC 15.8 MiB, and sensor 51.8 MiB (about 69.7 MiB total). The passive
sensor had no routed address and was not part of the forwarding path.

## Cleanup and repeatability

- **Scoped cleanup:** `containerlab destroy -t
  labs/ot-zone-conduit/probe/topology.clab.yml --cleanup`.
- **Second run:** passed; register 1 returned from 88 to the declared initial 73.
- **Residual check:** no `clab-ot-zone-conduit-probe-*` container, probe lab
  directory, or current-lab network remained after the script's exit trap.

## Unsupported behavior and fallback

No fallback or rename was required. The live claim is limited to synthetic
Modbus/TCP application data, Linux routing/filtering, NFLOG, passive packet
mirroring, and Suricata protocol parsing. The safety-instrumented-system boundary,
real PLC programming, vendor engineering tools, deterministic fieldbuses, TSN,
physical-process hazards, and plant authorization workflow remain evidence/concept
material as required by
`plans/enterprise-expansion/10-ot-zone-conduit.md`.
