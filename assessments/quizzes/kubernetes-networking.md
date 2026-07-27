# Topic Quiz — Kubernetes Service Networking

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `k8s-fabric`.

## Section 1 — Mechanisms (6 points)

### A1 — Turn a Service into a route (3 points)

State the separate role of a MetalLB `BGPPeer`, `IPAddressPool`, and
`BGPAdvertisement`, then explain why a `LoadBalancer` service is normally advertised as
a host route rather than the entire pool. (3 pts)

### A2 — Cluster versus Local (3 points)

Compare `externalTrafficPolicy: Cluster` and `Local` in terms of client source
preservation, cross-node forwarding, and which nodes advertise the VIP. (3 pts)

## Section 2 — Evidence reading (8 points)

### B1 — The service has an address but the fabric has no route

```text
kubectl get svc web:
EXTERNAL-IP 198.51.100.155

MetalLB controller:
allocated IP 198.51.100.155 from pool services

ToR BGP summary:
10.10.0.11 Estab 0
10.10.0.12 Estab 0

ToR route 198.51.100.155/32:
not found
```

1. Explain what is healthy and what is missing. (3 pts)
2. Name the most likely absent or mismatched MetalLB object. (2 pts)
3. Give three checks that prove publication, installation, and client delivery after
   repair. (3 pts)

## Section 3 — Application (10 points)

### C1 — Preserve client IP without creating a one-node service

A three-node rack requires `externalTrafficPolicy: Local` and two simultaneous ingress
paths for a three-replica service. Design pod placement, MetalLB advertisement behavior,
ToR BGP/ECMP, and failure verification. Explain the transient risk while endpoint and
route state converge. (10 pts)

## Section 4 — Design and troubleshooting (6 points)

### D1 — Route present, request hangs

The ToR installs the VIP through two node next hops, but a client request times out.
Give an ordered evidence chain from client routing and ToR FIB through BGP speakers,
service endpoints, node forwarding, and pod health. State why “the /32 exists” is not a
complete service check. (6 pts)

*Key: [`../answer-keys/quizzes/kubernetes-networking-key.md`](../answer-keys/quizzes/kubernetes-networking-key.md).*
