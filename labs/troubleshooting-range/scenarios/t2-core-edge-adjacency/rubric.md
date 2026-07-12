# Proctor rubric — TR-204 (confidential)

**Root cause:** edge's core1-facing routed interface is administratively disabled. **Pass:** 70/100 and `verify.sh` green. **Time:** 35 minutes.

Score monitoring-symptom validation (15), interface and OSPF neighbour evidence (35), minimal repair (25), and restored adjacency verification from both sides (25). Unnecessary changes to the redundant core2 path or no verification cap the score at 69.
