# NAT and Stateful Firewalls Quiz — Answer Key

**Total:** 20 points

## A. Translation and Policy (4 points)

### A1. Separate the functions (4 points)

- 1 point: DNAT changes a packet's destination, commonly publishing an internal service behind a public address or port.
- 1 point: SNAT or PAT changes the source so outbound private traffic can use a translated address and return through the translating device.
- 1 point: A stateful firewall decides whether a new flow is authorized and permits return traffic based on connection state.
- 1 point: A port forward still needs an inbound WAN/forward policy because translation selects a destination but does not itself authorize the new connection.

## B. Packet-Processing Order (6 points)

### B1. DNAT rule matches but the firewall drops the flow (6 points)

- 2 points: Explains that prerouting DNAT changes the destination before the packet reaches the forward-policy lookup, so the forward chain sees `172.16.10.20`, not public address `203.0.113.10`.
- 2 points: Corrects the forward rule to match the translated internal destination, required service port, ingress/egress zones, and new/established state as appropriate.
- 1 point: Checks NAT and firewall counters or connection-tracking state to confirm which rules process the packet.
- 1 point: Captures or observes the request at the server and verifies that the reply returns through the firewall.

## C. Zone-Policy Design (5 points)

### C1. Minimum policy matrix (5 points)

Award 1 point for each principle:

- Internet traffic reaches only the published DMZ web service on TCP 443 through DNAT plus an explicit WAN-to-DMZ permit.
- Corporate users receive only the required management and DMZ access.
- The DMZ web server can initiate only the required database flow, such as TCP 3306, with stateful return traffic allowed.
- Guest users can reach the Internet but not corporate, management, DMZ, or database networks.
- Corporate and guest outbound traffic uses SNAT/PAT as needed; all other new inter-zone flows are denied and useful denies are logged. The DMZ must not receive a general permit to pivot internally.

## D. Hairpin NAT (5 points)

### D1. Public name fails only from inside (5 points)

- 2 points: Identifies missing or incorrect NAT reflection/hairpin NAT. Internal clients resolve the public address and therefore traverse a path that requires the firewall to translate the public destination back to the internal server.
- 1 point: Notes that source translation may also be required so the server's reply returns through the firewall rather than going directly to the client and breaking the tracked flow.
- 1 point: Distinguishes the fault using internal DNS results, direct internal-address testing, packet captures, and connection/NAT state showing absent or asymmetric translation.
- 1 point: Verifies the public hostname from both internal and external clients after the change, including the complete request and return path.

## Remediation

| Weak area | Review |
|---|---|
| Edge NAT, forwarding policy, and connection state | `labs/enterprise-edge-nat-firewall/` |
| DMZ segmentation and least-privilege policy | `labs/enterprise-dmz/` |
| GUI-driven stateful firewall and NAT behavior | `labs/opnsense-ngfw-basics/` |
