# Enterprise Coverage Map

This is the program-wide inventory for advanced enterprise network engineering.
It complements the exam-specific [CCNP coverage map](coverage-map.md): that page
answers exam-blueprint questions; this page answers what can be practised,
troubleshot, or assessed across the whole curriculum.

The maintained source is [enterprise-coverage.yaml](enterprise-coverage.yaml).
Validate it after edits with:

```bash
python3 scripts/validate-enterprise-coverage.py
```

## Maturity levels

| Level | Meaning | Required evidence |
|---:|---|---|
| 0 | Absent | No maintained material; a planned target is explicitly named as planned. |
| 1 | Evidence/theory | Curated explanation or authentic/synthetic-labeled evidence pack. |
| 2 | Reference | Working deployment exposes the mechanism and has automated checks. |
| 3 | Practice | Student produces the core configuration from objectives and hints. |
| 4 | Troubleshooting | Symptom-led Break-It requires diagnosis and minimal repair. |
| 5 | Blind assessed | Runtime injector, idempotent clear, end-to-end verifier, proctor rubric, and live dry run. |

The validator rejects levels outside this range, nonexistent lab registrations,
level 3+ registrations without `check.sh`, and level 5 entries without scenario
metadata. A plan is not evidence: a topic remains level 0 until the promised
material is built and validated.

## Current inventory and planned targets

| Domain | Current position | Planned package targets |
|---|---|---|
| Campus LAN | Level 4 switching/access troubleshooting; level 3 enterprise design/services | WP-16 adds assessed cross-domain faults after source labs validate. |
| WAN and overlay | Level 4 VPN/segmentation and orchestrated provider-neutral overlay operations | `orchestrated-wan-overlay` provides controller/PKI, mTLS, two transports, policy, SLA, and certificate-fault recovery; vendor SD-WAN products remain level 1 theory/sandbox work. |
| Cloud and hybrid | Level 0 | WP-01 `cloud-hybrid-networking` to level 4. |
| Data center and DCI | Level 4 fabric/EVPN, routed DCI, and IP storage; level 1 FC/FCoE/RoCE evidence | WP-03 routed DCI and WP-11 authenticated multipath IP storage are live; hardware SAN/RoCE mechanisms remain evidence-only. |
| Internet edge | Level 4 BGP and prefix security | WP-07 `internet-peering-ixp` to level 4. |
| Wireless | Level 1 architecture/policy only | WP-02 live control/auth operations to level 4 when the radio probe passes; RF evidence to level 1. |
| Mobile | Level 0 | WP-05 private 5G to level 4 and mobile transport/timing to level 3. |
| Security | Level 4 access, policy, detection, and identity-aware zero trust | WP-06 `zero-trust-secure-access` is live; WP-14 advanced architecture remains planned. |
| Operations | Level 3 assurance, telemetry, and automation | WP-12 GitOps change pipeline to level 4. |
| IPv6 | Level 3 protocol/access/transition coverage | WP-08 systemic dual-stack capstone to level 4. |
| Carrier and physical | Level 0 | WP-04 packet-Ethernet handoff to level 4; physical/legacy evidence to level 1. |
| Voice and collaboration | Level 4 SIP/RTP/QoS troubleshooting | `enterprise-voice-sip-qos` provides live signaling/media, stateful NAT, measured contention, and one-way-audio diagnosis; PSTN/PoE/vendor clustering remain outside the live claim. |
| OT and IoT | Level 4 zone-and-conduit troubleshooting | `ot-zone-conduit` provides live synthetic Modbus/TCP, stateful policy, jump maintenance, passive DPI, and stale-historian diagnosis; physical process and SIS behavior remain outside the live claim. |
| Application delivery | Level 0 | WP-15 global application delivery to level 4. |
| Blind assessment | Level 0 in this program inventory | WP-16 creates three level-5 ranges only after their source labs have passed live validation. |

## Fidelity vocabulary

- **Live** means the stated protocol, policy, or data path runs locally and has
  an automated check.
- **Emulated** means the stated behavior is a bounded software analogue, not the
  original hardware/control plane.
- **Evidence-only** means fixtures or explanation are the learning material; it
  is never presented as a live measurement.
- **Product-only** means a vendor sandbox, licensed product, or external process
  is needed beyond this repository.
- **Hardware-required** means the repository cannot honestly reproduce the
  mechanism (for example RF propagation, optics, ASIC telemetry, or Fibre Channel
  hardware behavior).

Read the per-topic `fidelity` and `notes` fields in the YAML before treating a
topic as covered. Planned paths and target levels are deliberately recorded as
level 0, not as delivered coverage.

## Keeping the inventory honest

When a lab is added or materially changes scope:

1. Update its YAML topic, only raising the level after the required evidence exists.
2. Add the dated clean live validation result when one has been recorded.
3. Run the validator and its negative fixtures:

   ```bash
   scripts/test-enterprise-coverage-validator.sh
   ```

4. Follow the [fixture rules](https://github.com/jschless/networkingLabs/blob/main/labs/fixtures/README.md), [probe template](https://github.com/jschless/networkingLabs/blob/main/labs/templates/PROBE.md), [validation template](https://github.com/jschless/networkingLabs/blob/main/labs/templates/VALIDATION.md), and [image policy](image-policy.md).

The initial inventory intentionally does not backfill unverified historical live
validation dates. A blank `last_live_validation` is a gap to close, not a claim.
