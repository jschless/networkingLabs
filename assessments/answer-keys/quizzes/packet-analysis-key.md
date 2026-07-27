# Answer Key — Packet Analysis Topic Quiz

**Total:** 20 points

## A1 — Capture the right story (4 points)

- A host-edge capture sees local ARP/ND and the frame sent to its gateway; a routed
  transit capture sees forwarded IP traffic with link-local framing for that hop, not
  the original client ARP. (2)
- Capture filters limit packets written during collection, while display filters select
  from an already captured set for analysis. (1)
- An overly narrow capture filter can permanently omit the diagnostic protocol, return
  path, fragmentation/control message, or alternate port needed later. (1)

## B1 — The network delivered an application error (6 points)

1. Bidirectional IP delivery exists; the TCP three-way handshake completes; the server
   receives the requested URI and returns HTTP 503, which the client acknowledges. (3)
2. No packet in the supplied exchange supports a dropped call: the transaction reaches
   an application responder and receives an explicit error. (1)
3. Useful next artifacts include server/application logs tied to the request/time,
   upstream dependency health, load-balancer logs, resource metrics, or comparison with
   a known-good URI/request. Any two earn credit. (2)

## C1 — Prove a one-way failure (5 points)

- Capture simultaneously at the client/first hop, server-facing edge, and server host or
  firewall boundary using the full tuple in both directions. (2)
- If the server sends no SYN/ACK on its host interface, inspect listener/host firewall.
  If it leaves the server but vanishes before the client, walk the return route and
  intermediate captures. If it appears on firewall ingress but not egress with a deny
  counter/log, localize policy. (2)
- Preserve timestamps and sequence/ack numbers so packets from the same attempt are
  correlated rather than inferred from separate tests. (1)

## D1 — Slow encrypted connection (5 points)

- Measure DNS, TCP SYN/SYN-ACK/ACK, TLS handshake record timing, and time to first/last
  encrypted application bytes. (1)
- Retransmissions, duplicate ACKs, out-of-order packets, zero windows, and RTT can support
  loss, path, or endpoint-flow-control hypotheses. (1)
- TLS normally exposes transport behavior and limited handshake metadata but not
  encrypted HTTP status/body without endpoint keys/logs. (1)
- Correlate endpoint CPU/socket metrics, TLS/application logs, request identifiers, and
  dependency timing. (1)
- Compare captures at two boundaries and a known-good transaction before assigning
  network or application causality. (1)

## Remediation

| Weak area | Review |
|---|---|
| Capture placement, filters, protocol evidence, and application/network boundaries | `labs/packet-analysis-basics/` |
