# Proctor rubric — TR-108 (confidential)

**Root cause:** `corp1` was assigned `10.250.10.1/24`, which is the corporate
default gateway already owned by `acc1`, instead of its approved
`10.250.10.10/24` address. The conflicting local address also prevents a valid
default route through that gateway.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 15 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms the fault is isolated to one linked-up corporate endpoint | 15 | -10 if an upstream outage is assumed |
| Compares the endpoint address and route state with the documented corporate assignment | 25 | -15 for changing the switch before inspecting the client |
| Uses duplicate-address/ARP evidence to prove `10.250.10.1` is already in use | 25 | -15 if the address is changed without proving the conflict |
| Restores only `10.250.10.10/24` and the approved default gateway | 20 | -20 for adding workaround routes or changing the SVI |
| Verifies no duplicate response plus local and off-subnet reachability | 15 | -10 if only one ping is used |

Red flags: changing VLAN/routing state, disabling ARP behavior, or retaining the
gateway address on the client caps the score at 69. The scenario verifier is
required for a pass and checks the exact endpoint address and default route.
