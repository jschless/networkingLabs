# Feature Probe Record — `dci-evpn-multisite`

## Scope and decision

- **Feature and learning objective:** Prove standards-based eBGP EVPN type-5
  exchange between independent cEOS domains, remote VRF installation, VXLAN
  forwarding over a routed DCI, and an import-RT failure before claiming the
  planned six-router/four-endpoint practice lab.
- **Decision:** blocked — no completed lab is claimed.
- **Reason and fidelity statement:** The four-cEOS load-bearing probe passed,
  including the control-plane, RT import, and VXLAN data path.  The required
  six-cEOS topology did not pass its endpoint path: a type-5 route forwarded
  correctly between VRF loopbacks but not into a remote SVI-attached Linux
  endpoint on this exact cEOS image.  Replacing those endpoints with loopbacks
  would remove the required Linux endpoint and tenant-access fidelity, so it is
  not an authorized fallback.
- **Owner and date:** WP-03 / 2026-07-22.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic` |
| ContainerLab version | `0.74.1` (`1866b3a2b`) |
| Docker version | `29.5.3` |
| NOS image | `ceos:4.35.2F`, `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca` |
| EOS version | `4.35.2F-46221466.4352F` engineering build |
| Host memory before probe | 15 GiB total; 11 GiB available |
| Host disk before probe | 149 GiB available |

## Smallest load-bearing test

The disposable `/tmp/dci-evpn-multisite-probe` topology used two cEOS VTEP/border
roles (`a-bgw`, `b-bgw`), two local BGP/EVPN reflector roles (`a-rr`, `b-rr`),
one `10.255.10.0/30` DCI link, and PROD L3VNI `50010`.  Site A exported
`172.16.10.0/24` with RT `65010:50010`; Site B imported that RT.

```text
$ /usr/bin/time -f 'elapsed=%E maxrss=%MKB' containerlab deploy -t \
  /tmp/dci-evpn-multisite-probe/topology.clab.yml --reconfigure
ContainerLab created the four nodes and three links successfully. The terminal
runner did not retain the final /usr/bin/time line, so no elapsed/RSS figure is
invented for this blocked probe.

$ docker exec clab-dci-evpn-probe-b-bgw Cli -p 15 -c enable \
  -c 'show bgp evpn route-type ip-prefix ipv4'
RD: 10.10.0.3:50010 ip-prefix 172.16.10.0/24
  10.10.0.3 ... 65011 i

$ docker exec clab-dci-evpn-probe-b-bgw Cli -p 15 -c enable \
  -c 'show ip route vrf PROD 172.16.10.0/24'
B E 172.16.10.0/24 via VTEP 10.10.0.3 VNI 50010

$ docker exec clab-dci-evpn-probe-b-bgw Cli -p 15 -c enable \
  -c 'ping vrf PROD 172.16.10.1 repeat 3 timeout 2'
3 packets transmitted, 3 received, 0% packet loss
```

The DCI capture confirmed the actual overlay path, not a mock:

```text
10.20.0.3.50425 > 10.10.0.3.vxlan: VXLAN, flags [I], vni 50010
172.17.10.1 > 172.16.10.1: ICMP echo request
```

Changing Site B's import from `65010:50010` to `65010:59999` left the type-5
NLRI in `show bgp evpn route-type ip-prefix ipv4` but removed
`172.16.10.0/24` from `show ip route vrf PROD`; restoring the import RT restored
the FIB entry.  This validates the intended Break-It symptom.

Steady Docker samples were `1.282 GiB`, `1.278 GiB`, `1.223 GiB`, and
`1.245 GiB` for the two borders and two RR roles (about 5.03 GiB total).

## Full-topology gate and cleanup

A six-cEOS/four-Linux candidate topology was then deployed after building a
local `dci-endpoint:local` image from `alpine:3.22.1` (image
`sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1`;
`iproute2`, `iputils`, and `tcpdump`).  The six cEOS containers sampled at
approximately 7.7 GiB steady state, within the 10.5 GiB target.

Local and inter-site EVPN BGP sessions established, routes installed with the
expected VTEP/VNI, and VTEP-to-VTEP/VRF-loopback pings passed.  However,
`a-client` could not reach the type-5 destination `172.31.10.10` on a remote
SVI-attached endpoint.  Direct `ping vrf PROD` to a remote VRF loopback passed;
the same VNI route toward the SVI endpoint did not.  This means the prerequisite
tenant endpoint data path is not proven.

- **Destroy commands:** `containerlab destroy -t /tmp/dci-evpn-multisite-probe/topology.clab.yml --cleanup` and `containerlab destroy -t labs/dci-evpn-multisite/topology.clab.yml --cleanup`.
- **Checked:** `docker ps`, `ip netns list`, and `docker network ls` for both lab names.
- **Result:** no probe or candidate containers, namespaces, or networks remain.

## Unsupported behavior and follow-up

- L2 stretch, MAC mobility, duplicate-MAC handling, BUM containment, ESI, MLAG,
  BFD, and dual-DCI ECMP were not claimed or implemented.
- Re-probe the SVI/L3VNI endpoint behavior on an officially supported cEOS image
  or reduce the plan only through an explicit plan amendment.  Do not rename a
  VRF-loopback-only test as the planned multi-site tenant practice lab.
