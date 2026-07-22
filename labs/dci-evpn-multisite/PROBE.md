# Feature Probe Record — `dci-evpn-multisite`

## Scope and decision

- **Feature and learning objective:** eBGP EVPN type-5 exchange between independent cEOS fabrics, remote VRF installation, routed VXLAN forwarding, RT policy, and an import-RT diagnostic.
- **Decision:** go.
- **Reason and fidelity statement:** cEOS 4.35.2F passed the actual control and data path. The initial endpoint failure was not a platform limitation: ContainerLab's management default route won on the Linux endpoints. Replacing that route with the tenant gateway fixed return traffic. Borders must also participate in their local PROD L2VNI plus L3VNI.
- **Owner and date:** WP-03 / 2026-07-22.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic` |
| ContainerLab | `0.74.1` (`1866b3a2b`) |
| Docker | `29.5.3` |
| cEOS image | `ceos:4.35.2F`, `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca` |
| EOS version | `4.35.2F-46221466.4352F (engineering build)` |
| Endpoint base | `alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1` |
| Host memory before probe | 15 GiB total; 11 GiB available |

## Smallest load-bearing test

Four cEOS nodes (`a-bgw`, `a-rr`, `b-bgw`, `b-rr`) used one routed DCI and
PROD L3VNI 50010. Site A exported `172.16.10.0/24` with RT `65010:50010`; Site B
imported it. The following output proved received type-5, VRF installation, and
forwarding:

```text
RD: 10.10.0.3:50010 ip-prefix 172.16.10.0/24
B E 172.16.10.0/24 via VTEP 10.10.0.3 VNI 50010
3 packets transmitted, 3 received, 0% packet loss
10.20.0.3.50425 > 10.10.0.3.vxlan: VXLAN, vni 50010
```

Changing Site B's import to `65010:59999` retained the NLRI in the EVPN table
and removed the PROD FIB route. Restoring `65010:50010` restored it. Four-node
steady Docker samples totalled about 5.03 GiB.

## Endpoint/IRB correction

The six-cEOS/four-Linux candidate initially delivered ICMP requests to the remote
endpoint but replies exited its ContainerLab management interface. The endpoint
scripts were corrected from `ip route add default` to:

```text
ip route replace default via <tenant-gateway> dev eth1
```

A three-cEOS SVI/L3VNI probe then passed both directions between a VLAN-10 client
and VLAN-30 shared service. The full topology also passed inter-site PROD and
shared-service traffic. Each border has VLAN 10/L2VNI 10010 and PROD L3VNI 50010;
that local L2 participation is required for endpoint MAC resolution.

## Cleanup and exclusions

- **Destroy:** `containerlab destroy -t labs/dci-evpn-multisite/topology.clab.yml --cleanup`.
- **Checks:** `docker ps`, `ip netns list`, and `docker network ls` are scoped to the lab name after destroy.
- **Excluded:** vendor EVPN Multi-Site features, L2 stretch, MAC mobility, duplicate-MAC handling, BUM containment, ESI/MLAG, BFD, and dual-DCI ECMP.
