# Proctor rubric — TR-DE-101 (confidential)

**Root cause:** `carrier-nid-b` maps customer VLAN 120 to uncommissioned
provider S-VLAN 3999
instead of S-VLAN 3120 on UNI-to-core traffic. Replies are dropped by the
provider core's service allowlist; Gold and provider MTU are otherwise healthy.
**Pass threshold:** 70/100 and the scenario `verify.sh` must pass.
**Tier time band:** 20 minutes, provisional until a human blind pilot is recorded.

## Diagnostic decision path

1. Reproduce Silver and compare it with Gold from both demarcation perspectives.
2. Confirm the customer tags and committed MTU before inspecting provider mapping.
3. Compare the two NID OpenFlow tables and identify the single wrong mapping.
4. Replace only VLAN 120's UNI-to-core mapping on the affected NID.
5. Run `./range.sh verify` and record service separation plus bidirectional recovery.

## Weighted evidence milestones

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces Silver loss while bounding Gold and MTU as healthy | 20 | −10 if only one service is tested; −20 if scope is assumed |
| Confirms both customer tags and distinguishes UNI from provider-side evidence | 15 | −10 for changing endpoint addressing without evidence |
| Finds VLAN 120 mapped to S-VLAN 3999 rather than 3120 on `carrier-nid-b` | 30 | −15 for naming the service but not the faulty direction; −30 for guessing |
| Repairs only the VLAN-120 UNI-to-core flow | 20 | −20 for bridging customer VLANs together, `NORMAL`, a flow-table flush without exact replacement, or unrelated change |
| Runs the mandatory verifier and documents bidirectional service plus isolation | 15 | −15 if the verifier is not run; −8 if negative isolation is omitted |

Useful evidence commands:

```bash
./range.sh shell carrier-test-a
ping -I eth1.110 -c 2 192.0.2.2
ping -I eth1.120 -c 2 198.51.100.2

./range.sh shell carrier-nid-a
ovs-ofctl -O OpenFlow13 dump-flows br-service
./range.sh shell carrier-nid-b
ovs-ofctl -O OpenFlow13 dump-flows br-service
```

Minimal repair:

```bash
ovs-ofctl -O OpenFlow13 --strict del-flows br-service \
  "priority=100,in_port=1,dl_vlan=120"
ovs-ofctl -O OpenFlow13 add-flow br-service \
  "priority=100,in_port=1,dl_vlan=120,actions=push_vlan:0x88a8,set_field:0x1c30->vlan_vid,set_field:3->vlan_pcp,output:2"
```

Red flags: joining the customer VLANs, using `NORMAL`/`FLOOD`, changing tester
addresses, lowering the acceptance size, restarting a container, or making broad
unrelated flow changes caps the score at 69. Passing requires `./range.sh verify`.
