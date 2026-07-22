# WP-09 — Enterprise Voice, SIP, RTP, and QoS

## Outcome

Build `labs/enterprise-voice-sip-qos/`, a practice lab where phones register to a
real open-source call server, establish a SIP call, exchange RTP, traverse an
enterprise edge/SBC-like boundary, and retain acceptable media under congestion
through correct classification and scheduling. The student must distinguish call
signaling success from media-path success.

Target coverage: level 4.

## Fidelity

Live:

- voice VLAN and DHCP options where relevant;
- SIP registration, DNS/NTP dependencies, call setup/teardown;
- RTP/RTCP media flow and negotiated ports/codecs;
- DSCP marking/trust boundary, classification, shaping/queueing and measured loss/jitter;
- stateful firewall/NAT behavior causing one-way audio;
- SIP/RTP capture and call-detail/log correlation;
- high availability/failure discussion tied to real health checks.

Evidence-only unless the probe proves exact support:

- PoE budgets/delivery and LLDP-MED power policy;
- vendor call-manager/SBC clustering and emergency-calling integrations;
- PSTN/PRI/SIP-carrier operational ordering.

## Feature-probe gate

1. Pin Asterisk and SIPp/PJSUA-compatible images.
2. Prove two endpoints register, place a deterministic call, generate RTP for at
   least 60 seconds, and expose measurable sequence/loss/jitter data.
3. Prove cEOS LLDP-MED network-policy advertisement if planned; otherwise keep it
   evidence-only and still implement the voice VLAN explicitly.
4. Prove QoS on the selected bottleneck. Prefer cEOS MQC-like behavior only if
   supported in cEOS data plane; otherwise use Linux `tc` and state the syntax boundary.
5. Prove conntrack/NAT can deterministically create and repair one-way RTP.

## Lab type and platform

- Type: practice.
- `access1`, `dist1`: cEOS.
- `wan-edge`: VyOS/cEOS if exact SIP/NAT behavior is reliable; otherwise Linux nftables.
- `pbx`, `sbc`, `phone-a`, `phone-b`, `traffic-gen`, `dns-ntp`, `observer`: pinned Linux images.
- Reuse `qos-enterprise` traffic and check patterns where possible.

## Topology/addressing

```text
 phone-a -- access1 -- dist1 -- wan-edge -- sbc -- phone-b
                 |       |                 |
             dns/ntp    pbx           observer
                 \----- traffic-gen -----/
```

| VLAN/segment | Prefix | Purpose |
|---|---|---|
| Data | `10.109.10.0/24` | Workstation/background traffic |
| Voice | `10.109.20.0/24` | Phones and PBX |
| Voice services | `10.109.30.0/24` | PBX/DNS/NTP |
| WAN | `192.0.2.108/30` | Edge/SBC path |
| Remote voice | `10.109.40.0/24` | Remote endpoint |

Prebuild IP addressing, phone credentials, certificates if using TLS, PBX service,
test call scenarios, and traffic generator. Withhold switch voice policy, DHCP/DNS,
registrations, firewall pinholes/policy, DSCP trust, and queue configuration.

## Student task sequence

1. **Guided dependency survey:** inspect VLAN, DHCP, DNS SRV/A, NTP, PBX status and
   unregistered endpoints. Explain which failure each dependency would produce.
2. **Hinted access:** configure data/voice VLAN behavior, DHCP options and, if live,
   LLDP-MED network policy. Prove the phone obtains the voice address without giving
   an untrusted data client privileged placement.
3. **Hinted signaling:** configure DNS and phone/PBX registration. Place a call and
   trace INVITE/100/180/200/ACK/BYE with SDP addresses/ports.
4. **Hinted media:** permit and route negotiated RTP/RTCP, verify bidirectional media,
   and correlate stream statistics with call logs.
5. **Hinted QoS:** mark at the trusted endpoint/boundary, police remarking from
   untrusted data, configure a priority/bounded voice queue, create congestion, and
   compare RTP loss/jitter with and without policy.
6. **Hinted edge:** place a remote call across the stateful edge/SBC path and inspect
   address/port translation without enabling an unrestricted UDP range.
7. **Open capacity case:** add concurrent calls/background traffic and determine
   admission/queue capacity from measured codec bitrate plus overhead.
8. **Break-It:** SIP registers and calls connect, but one RTP direction advertises or
   traverses an unreachable private address because the edge policy/NAT helper is
   wrong. Diagnose from SDP, captures on both sides, conntrack and RTP stream stats;
   repair the intended media path without opening all UDP.

## Make the invisible visible

- Decode SIP/SDP and map it to actual RTP five-tuples.
- Graph or report RTP loss, jitter and sequence gaps under controlled congestion.
- Compare DSCP at phone, access, bottleneck and far endpoint.
- Correlate PBX call ID with firewall flow and packet capture.

## Automated checks

`check.sh` must assert at minimum:

1. Voice DHCP/DNS/NTP services healthy.
2. Both endpoints register.
3. Data client cannot join voice policy by self-marking/static address.
4. SIP call establishes and terminates cleanly.
5. RTP flows in both directions for the expected duration.
6. RTP loss/jitter stays within declared lab threshold under offered congestion.
7. Untrusted EF-marked data is remarked or policed.
8. Voice retains service while best-effort degrades predictably.
9. Remote call works through intended stateful policy.
10. Management/PBX admin ports are restricted.
11. Break-It fails bidirectional RTP while signaling assertions remain green.

## Planned files/docs

- Standard lab files, pinned voice image(s), SIPp scenarios, traffic profiles,
  call/RTP analysis script, `PROBE.md`, and `VALIDATION.md`.
- New `docs/tracks/collaboration/index.md` and wrapper, or an Enterprise subsection
  if one lab does not yet justify a full track. Make the choice during docs integration.
- PoE/PSTN/PRI evidence fixtures with provenance if included.

## Resource target

- 2 cEOS + 7 lightweight Linux.
- Target ≤ 6 GiB steady and ≤ 8 GiB peak.

## Definition of done

All master gates apply. Run at least five repeated calls, congestion/no-congestion
comparisons, bidirectional RTP checks, one-way-audio Break-It, and clean teardown.
Every codec/overhead/capacity number in the README must be derived from the pinned
call profile and observed captures.
