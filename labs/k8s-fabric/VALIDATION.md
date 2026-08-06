# k8s-fabric validation record

Status: **validated by the main agent**

This live record was collected on amd64. The architecture-aware checker also
accepts the documented arm64 cEOSarm 4.36.1F mapping under the canonical
`ceos:4.35.2F` tag, but no arm64 live-validation claim is made here.

## Clean deployment and baseline

- The final modified topology deployed successfully.
- `tor` reported EOS `4.35.2F-46221466.4352F` with engineering build ID
  `6f39e5bb-e6c7-4637-b931-ecb30d43e034`.
- Bootstrap reached its completion marker with exactly two Ready nodes:
  `k3s1` at `10.1.0.11` and `k3s2` at `10.1.0.12`.
- Four ready web pods were split two per node. One controller and two
  speakers were ready.
- The baseline had no MetalLB BGP resources and no EOS BGP process.

## Documented workflow

- EOS accepted the documented prefix-list, route-map, neighbor, and
  multipath solution. Before the remote configuration, both peers were
  `Active`.
- After applying the exact `BGPPeer`, `IPAddressPool`, and
  `BGPAdvertisement`, both peers were `Established` with zero received
  prefixes.
- `web-lb` received exactly `198.51.100.100`. The EOS BGP RIB held two paths
  through `10.1.0.11` and `10.1.0.12`, and the EOS FIB programmed exactly
  those two next-hops.
- Traceroute crossed the ToR and then an ECMP node next-hop (`.11` or `.12`),
  and external nginx HTTP succeeded.
- The solved checker reported `31 passed, 0 failed`.

## Supported fault and repair

- Running `break.sh` twice returned success both times.
- The broken checker reported exactly `28 passed, 3 failed`. The three
  failures were the intended repaired-state assertions: the Service used
  `Local`, all four pods ran on k3s1, and the FIB retained only `.11`.
- Both BGP sessions remained Established, HTTP remained healthy, and a fresh
  bounded log window showed exactly source `172.16.9.10`.
- Running `solution.sh` twice returned success both times. The final checker
  returned `31 passed, 0 failed`, placement returned to two pods per node,
  and the FIB returned to `.11` and `.12`.
- A fresh repaired `Cluster` log window showed translated node/pod bridge
  sources, consistent with the documented policy contrast.

## Resource and cleanup evidence

| Container | No-stream memory |
|-----------|-----------------:|
| client | 660 KiB |
| k3s1 | 487.2 MiB |
| k3s2 | 236.6 MiB |
| racksw | 1.191 MiB |
| tor | 1.232 GiB |

The sampled total was approximately 1.94 GiB. Safe destroy succeeded, leaving
no `clab-k8s-fabric` containers, Docker network, or stray PID, lock, or
`k3s.yaml` artifacts.

The `lab-tutor` skill was unavailable, so no tutor-validation claim is made.
