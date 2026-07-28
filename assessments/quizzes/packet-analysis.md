# Topic Quiz — Packet Analysis

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `packet-analysis-basics`.

## Section 1 — Mechanisms (4 points)

### A1 — Capture the right story (4 points)

Explain how capture location changes visibility of ARP, routed traffic, and return
packets. Contrast a capture filter with a display filter and give one risk of filtering
too narrowly during collection. (4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — The network delivered an application error

```text
1 client -> server TCP SYN
2 server -> client SYN, ACK
3 client -> server ACK
4 client -> server HTTP GET /api/status
5 server -> client HTTP/1.1 503 Service Unavailable
6 client -> server ACK
```

1. State what the trace proves at the IP, TCP, and HTTP layers. (3 pts)
2. Explain why “the network dropped the API call” is unsupported. (1 pt)
3. Name two additional artifacts needed before assigning the application root cause.
   (2 pts)

## Section 3 — Application (5 points)

### C1 — Prove a one-way failure

A client SYN crosses two routers and reaches a server, but the client sees no response.
Choose capture points and filters that distinguish no server reply, a bad return route,
and a firewall drop. State the packet difference expected for each. (5 pts)

## Section 4 — Design and troubleshooting (5 points)

### D1 — Slow encrypted connection

Describe what a packet capture can and cannot establish about a slow TLS application.
Include handshake timing, retransmissions, duplicate ACKs, TLS metadata, and the
endpoint/application evidence needed beyond the capture. (5 pts)

<!-- site-include-end -->

*Key: [`../answer-keys/quizzes/packet-analysis-key.md`](../answer-keys/quizzes/packet-analysis-key.md).*
