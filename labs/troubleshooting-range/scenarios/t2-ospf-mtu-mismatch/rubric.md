# Proctor rubric — TR-205 (confidential)

**Root cause:** `core1 eth3` uses MTU 1400 while `core2 eth3` uses MTU 1500,
leaving their OSPF adjacency in ExStart because database-description MTU
validation fails.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms the exact neighbor is stuck in ExStart while redundant reachability works | 15 | -5 if only the neighbor count is cited |
| Compares OSPF interface state and link MTU on both peers | 30 | -15 for changing timers or authentication without evidence |
| Explains why unequal MTUs prevent database-description exchange | 20 | -10 if the state transition is not interpreted |
| Restores the golden MTU rather than disabling mismatch detection | 20 | -20 for `mtu-ignore` or an unrelated link change |
| Verifies Full state from both peers and a client service path | 15 | -10 if verification is control-plane only |

Red flags: adding `ip ospf mtu-ignore`, restarting either router, or modifying
the alternate paths caps the score at 69. The scenario verifier is required
for a pass.
