# Feature Probe Record — `cloud-hybrid-networking`

## Scope and decision

- **Feature and learning objective:** Prove Linux route domains/VRFs, nftables conntrack policy, source-aware DNS, and cEOS↔FRR eBGP before claiming a provider-neutral hybrid transit lab.
- **Decision:** go.
- **Reason and fidelity statement:** Linux route table 101/VRF creation and nftables hooks worked on the host kernel. cEOS 4.35.2F and FRR 10.5.0 established eBGP. The upstream FRR image lacked nft; the documented custom image adds real Linux tools rather than substituting a mock.
- **Owner and date:** WP-01 / 2026-07-22.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic` |
| ContainerLab version | `0.74.1` (`1866b3a2b`) |
| Docker version | `29.5.3` |
| cEOS image | `ceos:4.35.2F`, image `sha256:f27a0e7dba17…` |
| FRR image | `quay.io/frrouting/frr:10.5.0@sha256:fc7f887ab4d8da06f481a4f8d59afded88b3c5823f03610a7e808f7eba45eeea` |
| Host memory before probe | 15 GiB total, 11 GiB available |

## Smallest load-bearing test

Disposable topology: one cEOS edge at `169.254.60.1/30` and one FRR transit at
`.2/30`, with cEOS AS 65060 and FRR AS 65100.

```text
$ containerlab deploy -t /tmp/cloud-hybrid-probe/topology.clab.yml --reconfigure
elapsed=0:25.86 maxrss=40864KB

$ docker exec clab-cloud-hybrid-probe-edge Cli -p 15 -c enable -c 'show ip bgp summary'
169.254.60.2 4 65100 ... Estab ... PfxRcd 0 ... PfxAdv 1

$ docker exec clab-cloud-hybrid-probe-transit vtysh -c 'show bgp summary json'
"169.254.60.1": { "remoteAs":65060, "state":"Established", "pfxRcd":1 }

$ ip link add vrf-a type vrf table 101; ip link set vrf-a up
$ ip route add table 101 10.61.10.0/24 via 169.254.60.1
10.61.10.0/24 via 169.254.60.1 dev eth1
```

The raw FRR image reported `nft: command not found`. The custom-image probe used:

```text
$ docker build -t cloud-lab-probe:local /tmp/cloud-hybrid-probe
elapsed=0:02.81 maxrss=53152KB
$ docker run --rm --cap-add NET_ADMIN --cap-add NET_RAW cloud-lab-probe:local ...
table inet probe { chain forward { type filter hook forward priority filter; policy drop; ct state established,related counter ... accept } }
BIND 9.20.23 (Stable Release)
conntrack v1.4.8 (conntrack-tools)
```

Exact custom package command: `apk add --no-cache bind bind-tools conntrack-tools curl iproute2 iputils jq nftables openssl python3 tcpdump`.
This is the plan-authorized custom `cloud-lab:local` image, based on the pinned FRR digest.

## Cleanup and repeatability

- **Destroy command:** `containerlab destroy -t /tmp/cloud-hybrid-probe/topology.clab.yml --cleanup`.
- **Checked:** `docker ps`, `ip netns list`, and `docker network ls` for `cloud-hybrid-probe` names.
- **Result:** the first deploy established BGP; the disposable topology was destroyed and no probe-named containers, namespaces, or networks remained. A second deploy again created the cEOS/FRR nodes; the host runner returned before its post-deploy command chain, so final repeatability is recorded by the full lab clean walk in `VALIDATION.md`.

## Unsupported behavior and fallback

- The probe does not represent provider APIs, managed transit HA, IAM, billing, private-circuit provisioning, AZ underlay, or GUIs.
- No fallback/rename was needed. The Linux routers explicitly model route-table semantics; they are not claimed to be AWS TGW, Azure Virtual WAN, or GCP NCC implementations.
