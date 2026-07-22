# Validation Record — `dci-evpn-multisite`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-22 / WP-03 |
| Host OS/kernel | Linux `5.15.0-181-generic` |
| ContainerLab/Docker | 0.74.1 (`1866b3a2b`) / 29.5.3 |
| Images | `ceos:4.35.2F` (`sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`); `dci-endpoint:local` (`sha256:20c5b8a2ef30ae0f79f97dbc98aa582f78b2c0774c804711569fb9b13335bc40`) from pinned `alpine:3.22.1` |
| Repository | `codex/lab-dci-evpn-multisite` |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Build | `docker build -t dci-endpoint:local -f labs/dci-evpn-multisite/Dockerfile.endpoint labs/dci-evpn-multisite` | 1.6 s package layer (plus 0.2 s image export) | endpoint image is 13 MiB installed packages |
| Deploy/readiness | `./scripts/lab.sh deploy dci-evpn-multisite`; wait for cEOS BGP agent | ContainerLab creates ten nodes/eleven links in about 4 s; BGP becomes usable during the cEOS boot window (about 1–2 min) | six cEOS: 7.747 GiB total; endpoints: under 1 MiB each |
| Student path | Manually applied only the README DCI underlay routes, eBGP EVPN, remote RT imports, and PROD export route maps | passed twice from the intentionally incomplete startup state | within steady envelope |
| Healthy check | `./labs/dci-evpn-multisite/check.sh` | 18 passed, 0 failed (twice) | within steady envelope |
| Break-It/repair | Wrong Site-B import RT, expected check failure, minimal RT repair, pass | 14 passed / 4 expected failures, then 18 passed | within steady envelope |
| DCI fault/recovery | Shut `a-bgw Ethernet2`, test, `no shutdown`, check | Remote PROD failed; local shared service passed; restored check 18/0 | within steady envelope |
| Destroy/redeploy/destroy | Scoped ContainerLab destroy, no residuals; clean redeploy/repeat; final scoped destroy | 3 s each destroy | no current-lab resources remain |

## Positive and negative evidence

- PROD Site A to Site B and Site B to shared-service pings passed after the remote
  RT was imported at both border and leaf.
- `show ip route vrf PROD` showed remote VTEPs and VNI 50010.
- DEV source-address pings had no route to remote DEV or shared service.
- The DCI route map matched only the local PROD RT and denied unmatched exports.
- `tcpdump -nli eth2 -c 2 'udp port 4789'` on `a-bgw` captured a real remote
  request and reply encapsulated with VNI 50010:

  ```text
  10.20.0.1.58169 > 10.10.0.3.vxlan: VXLAN, flags [I] (0x08), vni 50010
  172.17.10.20 > 172.31.10.10: ICMP echo request
  ```

- The RT Break-It left the remote `ip-prefix` NLRI visible in `show bgp evpn
  route-type ip-prefix` but removed it from the Site-B PROD FIB. The intended
  failures were the two Site-B remote type-5/FIB assertions and the two
  cross-site PROD endpoint pings; the DCI session remained Established.
- Initial Linux endpoint failure was diagnosed with tcpdump: request arrived at the
  endpoint; the management default route sent the reply away. `ip route replace`
  corrected that real host-routing issue.

## Limitations and cleanup

- No L2 stretch, MAC mobility, BUM, ESI/MLAG, BFD, or dual-DCI ECMP claim.
- Alpine 3.22.1 and cEOS 4.35.2F are pinned lab dependencies; refresh before the
  next curriculum cycle.
- Repository gates are recorded in the delivery commit; the final scoped destroy
  confirmed no `clab-dci-evpn-multisite-*` container, network, or namespace remains.
