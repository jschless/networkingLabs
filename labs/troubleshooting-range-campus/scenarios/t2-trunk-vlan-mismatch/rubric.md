# Proctor rubric — CR-304 (confidential)

**Root cause:** The `acc1 Port-Channel1` trunk was reduced to VLAN 10 only. Corporate VLAN 10 stays healthy while voice VLAN 20 cannot cross the access-to-distribution uplink.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Establishes the VLAN-specific scope from corporate and voice probes | 20 | -15 for treating it as a complete uplink failure |
| Uses trunk allowed/active/forwarding state to localize the mismatch | 35 | -20 for changing endpoint addressing first |
| Restores the approved VLAN allowance without rebuilding the bundle | 25 | -20 for replacing the Port-Channel or moving voice into corporate VLAN |
| Verifies gateway and inter-VLAN service from both user populations | 20 | -15 for testing only the formerly failing endpoint |

Red flags: disabling STP, changing SVI addresses, or restarting containers caps the score at 69. The scenario verifier is required for a pass.
