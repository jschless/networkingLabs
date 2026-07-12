# Proctor rubric — TR-202 (confidential)

**Root cause:** core2's branch-facing routed interface is administratively disabled, taking down the branch OSPF adjacency. **Pass:** 70/100 and `verify.sh` green. **Time:** 35 minutes.

Score isolation scope (15), OSPF neighbour and interface-state evidence (35), minimal interface repair (25), and branch-client verification (25). Restarting nodes or adding static routing before proving the adjacency fault deducts 20; no client verification caps at 69.
