# WP-16 — Blind Assessment Expansion

## Outcome

Convert representative failures from the new practice labs into blind, persistent,
proctored troubleshooting ranges that follow
`labs/troubleshooting-range/scenarios/AUTHORING.md`. Practice-lab Break-It exercises
are not level-5 coverage; these ranges add symptom-only tickets, transcripts,
rubrics, runtime injection, idempotent reset and end-to-end verifiers.

No range work begins until its source labs have completed clean live validation.

## Range architecture

Build three separately deployed ranges rather than one impossible all-enterprise
topology. Each has its own topology version, health gate, golden reset, attempt
directory and `range.sh` based on the proven existing pattern.

### A. `troubleshooting-range-hybrid-access`

Source packages: cloud, wireless control/auth where host-safe, zero trust, dual stack,
SD-WAN operations, global application delivery.

Target topology: dual-stack campus edge, cloud-like transit/app domains, identity
PEP/origin, DNS, two WAN transports, lightweight app delivery. Wireless RF and real
SD-WAN product state may remain external evidence tickets unless reset is reliable.

Initial 12-ticket catalog:

| Tier | Ticket symptom | Root-cause family | Verifier must reject |
|---:|---|---|---|
| T1 | One cloud app denied, routing healthy | Workload policy/SG port | Opening broad subnet ACL |
| T1 | Managed user denied protected route | Client cert expired/untrusted | Disabling TLS verification |
| T1 | IPv6 client lacks DNS/default | RA/RDNSS or DHCPv6 flag | IPv4-only workaround |
| T1 | GSLB marks one site down | Probe source ACL | Forced static DNS answer |
| T2 | Hybrid route present, replies absent | Wrong transit association/return table | Host static route |
| T2 | Corp SSID visible, EAP fails | RADIUS/EAP trust chain | Disabling server validation |
| T2 | Guest local breakout works, private segment leaks | SD-WAN segment policy | Endpoint firewall mask |
| T2 | AAAA clients stall, A clients work | IPv6 PMTUD/return route | Removing AAAA |
| T3 | PEP tests pass but app exposed | Direct origin bypass | App host firewall only if architecture requires PEP path assertion |
| T3 | App intermittently chooses dead site | DNS cache/health timing | `/etc/hosts` override |
| T3 | Underlays green, branch routes absent | Edge certificate/control-plane lifecycle | Static overlay route |
| T3 | Cloud HTTPS reaches app but inspection sees one direction | Asymmetric route-table propagation | Disabling stateful inspection |

### B. `troubleshooting-range-dci-edge`

Source packages: DCI, carrier handoff, internet peering, storage networking, advanced
security architecture.

Initial 12-ticket catalog:

| Tier | Ticket symptom | Root-cause family | Verifier must reject |
|---:|---|---|---|
| T1 | One carrier VLAN unavailable | Wrong UNI/S-VLAN map | Bridging customer VLANs together |
| T1 | Storage path degraded | One path admin/MTU state | Ignoring failed path |
| T1 | Peer prefix missing | Stale approved-prefix object | Permit-any policy |
| T1 | Public app works only direct | WAF/origin policy | Exposing origin |
| T2 | Remote PROD absent, EVPN sessions up | Route-target mismatch | Static VRF route |
| T2 | Large circuit tests fail | Service MTU mismatch | Fragmenting test or lowering acceptance size |
| T2 | New peer prefix rejected | IRR/RPKI/max-prefix distinction | Disabling all validation |
| T2 | iSCSI session up, large I/O stalls | Intermediate MTU | Small-ping-only verification |
| T3 | Site-local apps healthy, inter-site fails after maintenance | Border/DCI policy/next hop | L2 stretch workaround |
| T3 | Public path bypasses inspection silently | Shadow rule/asymmetry | Broad allow or disabling state |
| T3 | Peering blackhole exceeds intended scope | Community/prefix scope | Removing all RTBH support |
| T3 | Healthy service withdrawn at one site | Health/OAM evidence disagreement | Hard-coded advertisement |

### C. `troubleshooting-range-specialized-services`

Source packages: private 5G, mobile transport, enterprise voice, OT/IoT.

Initial 9-ticket catalog:

| Tier | Ticket symptom | Root-cause family | Verifier must reject |
|---:|---|---|---|
| T1 | UE rejected during registration | Subscriber/PLMN mismatch | Anonymous/open subscriber policy |
| T1 | Phone cannot register | DNS/NTP/credential dependency | Static PBX IP if DNS is required |
| T1 | Historian stops updating | Expired maintenance/conduit rule | Direct enterprise-to-PLC allow |
| T2 | UE registered, no private app | DNN/UPF/return route | Broad NAT/default mask |
| T2 | Call connects, one-way audio | SDP/NAT/stateful path | Any-UDP allow |
| T2 | OT HMI healthy, historian stale | IDMZ return policy | Flattening zones |
| T3 | Mobile control unstable only under load | QoS trust/timing congestion | Overprovision/disable classification |
| T3 | Voice quality bad, signaling healthy | DSCP trust/queue policy | Mark all traffic EF |
| T3 | Remote maintenance works but bypasses jump host | Shadow route/policy | Endpoint-only block |

## Ticket contract

Every scenario directory contains:

```text
metadata.env
ticket.md
inject.sh
clear.sh
verify.sh
rubric.md
```

- Ticket wording is symptom-only and names impact/reporter, not cause, protocol,
  node or command.
- Tier follows diagnostic distance, not technology difficulty.
- Injector changes runtime-only or writable in-container state and proves the
  reported symptom before success; it never edits the baseline startup configuration.
- Clear is idempotent and no repair/reset requires container restart.
- Verify proves intended architecture and negative policy, not only restored ping.
- Rubric has weighted evidence milestones, decision path, time band, pass threshold,
  deductions, red flags and mandatory verifier.
- Parameterize fault location only where the verifier and rubric remain exact.

## Range build sequence

For each range:

1. Design topology/addressing/resource/golden reset in `DESIGN.md`.
2. Prototype every new reset mechanism before topology growth.
3. Build health gate covering control plane, services, positive paths, negative policy,
   queue/qdisc, cert/time state and stale caches relevant to planned tickets.
4. Build `range.sh` by reusing tested functions, not copy/paste divergence.
5. Hand-build one T1 and one T3 reference ticket and run full transcript/rubric pilot.
6. Freeze `topology_version` before parallel ticket authoring.
7. Add remaining tickets on separate branches; one owner integrates catalog/shared files.
8. Run structural validator, lint/docs, and live
   `status → start → diagnose → minimal repair → verify → reset` for every ticket.
9. Conduct a real human pilot before publishing qualification time bands.

## Resource target and deployment constraints

- Each range separately deployed; none concurrently required.
- Target ≤ 8 GiB steady and ≥ 4 GiB host headroom during assessment.
- Scenario injection/reset target ≤ 15 seconds except real protocol convergence;
  health gate target ≤ 30 seconds.
- Heavy wireless, NGFW, Keycloak or 5G components may require smaller dedicated
  ranges rather than violating reset/reliability requirements.

## Automated checks and validation

In addition to repository gates:

```bash
python3 scripts/validate_ticket.py <scenario-dir>
cd labs/<range>
./range.sh status
./range.sh start <scenario>
./range.sh verify
./range.sh reset
./range.sh status
```

Every rubric evidence command must be executed during live validation and produce
the deduction claimed. Save sanitized transcript evidence in `VALIDATION.md` or a
package validation record.

## Definition of done

- Three ranges deploy/reset cleanly and meet resource targets.
- All initial tickets pass structural and live dry-run gates.
- No ticket duplicates another ticket's root cause, symptom, path and evidence pattern.
- At least one human completes a blind pilot in each range; rubrics/time bands are
  adjusted from observed behavior.
- Coverage map promotes a topic to level 5 only after the corresponding ticket and
  human-pilot evidence exist.
