# Proctor rubric — TR-201 (confidential)

**Root cause:** acc1 has a more-specific static Null0 route for the branch subnet, overriding OSPF. **Pass:** 70/100 and `verify.sh` green. **Time:** 35 minutes.

Score scope comparison (20), route-table/longest-prefix evidence (35), minimal route removal (25), and endpoint validation (20). Static workarounds or unrelated OSPF changes deduct 20; no endpoint verification caps at 69.
