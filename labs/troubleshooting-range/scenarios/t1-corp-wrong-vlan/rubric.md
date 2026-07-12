# Proctor rubric — TR-104 (confidential)

**Root cause:** `acc1 Ethernet3` is assigned to VLAN 20 instead of corporate VLAN 10. **Pass:** 70/100 and `verify.sh` green. **Time:** 15 minutes.

Score client scope (15), port/VLAN evidence (35), precise VLAN correction (25), and endpoint plus switch verification (25). Changing the client IP or adding a static route without switch evidence deducts 20; no verification caps at 69.
