# Sanitized live transcript — TR-DE-101

**Date:** 2026-07-29 UTC
**Topology:** `1.0.0` candidate, subsequently frozen unchanged

## Start and symptom

```text
./range.sh start t1-carrier-svlan-map
Results: 26 passed, 0 failed
Ticket symptom is active: Silver is unavailable while Gold and its committed MTU remain healthy.
t1_start_elapsed=4.72
```

Rubric evidence:

```text
Gold 192.0.2.1 -> 192.0.2.2: 2 transmitted, 2 received
Silver 198.51.100.1 -> 198.51.100.2: 2 transmitted, 0 received
carrier-nid-a VLAN 120: set_field:7216->vlan_vid
carrier-nid-b VLAN 120: set_field:8095->vlan_vid
```

`7216` is VLAN-present-bit plus S-VLAN 3120; `8095` is the uncommissioned 3999
mapping. Both NID tables and the healthy Gold/1600-byte path established the
fault scope.

## Minimal repair and verifier

The live repair deleted only NID-B's strict VLAN-120 UNI flow and installed the
3120/PCP-3 replacement. Result:

```text
PASS: Gold and Silver pass bidirectionally at the committed MTU, retain distinct service mappings, and no broad bridge workaround exists.
t1_verify_elapsed=0.20
```

An adversarial priority-200 `actions=NORMAL` rule on all three provider bridges
restored apparent Silver reachability but was rejected:

```text
EXPECTED_FAIL verifier rejected broad NORMAL workaround
ERROR: broad bridge forwarding bypasses explicit service mappings
```

After removing only those adversarial rules, verify passed. Clear ran twice
successfully. Golden reset returned health 26/26 without a restart.
