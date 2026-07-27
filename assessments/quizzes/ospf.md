# Topic Quiz — OSPF

**Time:** 35 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** the nine labs in the OSPF track. The guided OSPF debug labs are
recommended.

This quiz tests OSPF as a protocol rather than one remembered topology. Unless a question
says otherwise, configuration syntax is Arista EOS as used by the labs.

---

## Section 1 — Mechanisms (6 points)

### A1 — Boundaries and route types (3 points)

r1 is internal to area 10, r2 is the area 10/area 0 ABR, and r4 is an ASBR in area 0.
r1 installs r4's loopback as `O IA` and a prefix redistributed by r4 as `O E1`.

1. Which LSA type carries r4's loopback into area 10, and which router originates that
   LSA? (1 pt)
2. Which LSA type carries the redistributed prefix, and which router originates it?
   (1 pt)
3. What extra cost does E1 include that E2 does not? (1 pt)

### A2 — Adjacency admission (3 points)

Two changes can make otherwise healthy OSPF interfaces stop recognizing each other:
one side of an area is configured as stub while the other remains normal, or the two
sides use different message-digest keys.

1. What OSPF packet and field expose the stub-area disagreement? (1 pt)
2. What is validated in the authentication failure? (1 pt)
3. Why do these failures prevent a neighbor from reaching `ExStart`, while an MTU
   mismatch commonly parks a neighbor there? (1 pt)

---

## Section 2 — Evidence reading (8 points)

### B1 — A default route that outlived its exit

Users behind `core` report that internet traffic is being black-holed. The OSPF
adjacency to `edge` is still Full.

```text
core# show ip route 0.0.0.0/0
O E2  0.0.0.0/0 [110/1] via 10.12.0.2, Ethernet1

edge# show ip route 0.0.0.0/0
% Network not in table

edge# show running-config section router ospf
router ospf 1
   router-id 10.0.0.2
   network 10.12.0.0/30 area 0.0.0.0
   default-information originate always
```

1. Explain why `core` still has the default, including its route code and LSA type.
   (2 pts)
2. Why does the Full adjacency neither prove internet reachability nor withdraw this
   route? (2 pts)
3. Give two safer origination policies and the operational difference between them.
   (2 pts)
4. State one control-plane check and one user-perspective check that together prove the
   repair. (2 pts)

---

## Section 3 — Application (10 points)

### C1 — Multi-area ABR on EOS (6 points)

Configure r2 as an ABR with OSPF process 1 and router ID `10.0.0.2`.

- `Loopback0` belongs to area 0 and must be passive.
- `Ethernet1` belongs to area 0 and must use message-digest authentication, key ID 7,
  secret `BACKBONE`.
- `Ethernet2` belongs to area 10.
- Area 10 is a stub area.
- Prefixes from area 10 must be advertised toward area 0 as `10.10.0.0/16`.

Interfaces and addresses already exist. Write the OSPF process and interface
configuration required on r2. You do not need to configure any other router.

### C2 — OSPFv3 on EOS (4 points)

On r6, `Ethernet1` and `Loopback0` already have IPv6 addresses. Put both in OSPFv3 area
0, keep the loopback passive, and set the required router ID to `10.0.0.6`. Write the
interface and process configuration.

---

## Section 4 — Design and troubleshooting (6 points)

### D1 — The impossible transit area

A new site's area 30 connects to ABR b1. The only path from b1 toward an area 0 ABR is
through area 20, which is already an NSSA because it contains an ASBR. An engineer
proposes an OSPF virtual link through area 20.

1. Explain exactly why the proposal is invalid. (2 pts)
2. Give a defensible temporary repair and the preferred long-term design. Include the
   principal risk or trade-off of the temporary repair. (2 pts)
3. Name two pieces of post-change evidence that prove inter-area routing is restored,
   not merely that a physical neighbor is up. (2 pts)

---

*End of OSPF quiz. Key: [`../answer-keys/quizzes/ospf-key.md`](../answer-keys/quizzes/ospf-key.md).*
