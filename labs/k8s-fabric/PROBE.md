# k8s-fabric pre-remediation probe

This file preserves evidence gathered by the main agent against the previous
FRR-based implementation. It is not final validation of the remediated cEOS
lab.

## Observed workflow

- Cold bootstrap completed successfully with two Ready k3s nodes, MetalLB,
  and four nginx replicas.
- The baseline had no BGP configuration.
- After the old ToR and MetalLB configuration, both node peers reached
  Established.
- MetalLB allocated `198.51.100.100`; the old ToR learned the VIP as a /32,
  installed next-hops `10.1.0.11` and `10.1.0.12`, and forwarded external
  HTTP successfully.
- Fresh access-log windows under `externalTrafficPolicy: Local` showed the
  external source `172.16.9.10`.
- Pinning all endpoints to k3s1 withdrew the `.12` path while the service
  remained reachable through `.11`.
- Repair restored the two-path route.
- The old checker completed `11 passed, 0 failed`.

## Resource snapshot

| Container | Memory |
|-----------|--------|
| client | 2.465 MiB |
| k3s1 | 525.9 MiB |
| k3s2 | 255.4 MiB |
| racksw | 9.504 MiB |
| tor (old FRR role) | 25.89 MiB |

## Limitation

This evidence proves the Kubernetes/MetalLB behavior and the old FRR data
path only. The final cEOS 4.35.2F configuration, native JSON shape, checker,
fault, and repair still require a clean live validation.
