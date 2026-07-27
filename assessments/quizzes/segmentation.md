# Topic Quiz — VRFs and Routed Segmentation

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `vrf-lite` and `black-core-routing`.

## Section 1 — Mechanisms (6 points)

### A1 — Separate tables, shared hardware (3 points)

Explain how VRF-Lite isolates two tenants on the same router, including interface
membership, route lookup, and overlapping address space. State what happens on EOS when
an addressed interface is moved into a VRF after the IP address was configured. (3 pts)

### A2 — Controlled communication (3 points)

Contrast an accidental interface/route placement with an intentional route leak. Explain
why a one-way leaked prefix may still be insufficient for a working application flow.
(3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — The shared service has no reply

`VRF-BLUE` clients should reach one service in `VRF-RED`.

```text
pe1# show ip route vrf VRF-BLUE 10.10.50.10
S 10.10.50.10/32 [1/0] via 10.10.12.2, Ethernet1, resolve-vrf VRF-RED

pe1# show ip route vrf VRF-RED 10.20.60.0/24
% Network not in table

service# ip route
default via 10.10.50.1

client-blue# curl 10.10.50.10
connect timeout
```

1. Explain what the BLUE route proves and what it does not prove. (2 pts)
2. Identify the missing forwarding requirement. (2 pts)
3. Propose a least-privilege repair rather than merging the VRFs. (2 pts)
4. Give two tests that verify both reachability and retained isolation. (2 pts)

## Section 3 — Application (10 points)

### C1 — Design shared services for three tenants

RED, BLUE, and GREEN require access to the same DNS service, but must not reach one
another's client prefixes. Design the routing and policy model, including:

- which exact prefixes are imported or leaked;
- return reachability;
- where service-port policy is enforced;
- how overlapping tenant addresses affect the design; and
- evidence proving no unintended transit exists.

(10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — A black core learned a red route

An encrypted routed overlay carries `10.40.0.0/16`. The transport core should know only
encryptor transport endpoints, but `core2` now installs `10.40.0.0/16` through its
underlay IGP. Explain the separation failure, give the minimum policy repair, and specify
route-table plus packet-capture evidence that proves the core is black again without
breaking the overlay. (6 pts)

*Key: [`../answer-keys/quizzes/segmentation-key.md`](../answer-keys/quizzes/segmentation-key.md).*
