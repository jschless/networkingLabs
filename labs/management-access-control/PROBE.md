# Feature Probe Record — `management-access-control`

## Scope and decision

- **Feature and learning objective:** prove that the locally installed cEOS
  image can terminate SSH and HTTPS eAPI on routed data interfaces and enforce
  a source/service policy at the system control plane with observable
  first-match counters.
- **Decision:** go; use cEOS for the learned device and Linux only for the two
  incidental traffic generators.
- **Reason and fidelity statement:** cEOS 4.35.2F accepted and activated an
  IPv4 ACL under `system control-plane`. The policy protected traffic
  destined to the router itself without requiring data-plane interface ACLs.
  This is a router management-plane exercise, not a Linux `iptables`
  substitute.
- **Owner and date:** Codex, 2026-07-31.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | client/server `29.5.3` |
| cEOS image | `ceos:4.35.2F`, image ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`, 2,562,840,665 bytes |
| Reported NOS | `4.35.2F-46221466.4352F (engineering build)` |
| Linux client image | `ops-lab:local`, image ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, 68,762,000 bytes |
| Host capacity | 15 GiB RAM and 2 GiB swap; the pre-probe free-memory value was not captured. After final cleanup, 12 GiB was available, swap use was 0 B, and 139 GiB disk was available. |

## Smallest load-bearing test

A disposable topology under
`/tmp/management-access-ceos-probe-019fb7` first tested one cEOS node, then
one cEOS node connected to the two Linux sources used by the final lab. The
temporary directory and topology were removed after the decision.

```bash
containerlab deploy \
  -t /tmp/management-access-ceos-probe-019fb7/topology.clab.yml
docker exec clab-management-access-ceos-probe-device1 \
  Cli -p 15 -c "show management ssh"
docker exec clab-management-access-ceos-probe-device1 \
  Cli -p 15 -c "show management api http-commands"
docker exec clab-management-access-ceos-probe-admin1 \
  nc -zvw 3 192.168.99.1 22
docker exec clab-management-access-ceos-probe-admin1 \
  nc -zvw 3 192.168.99.1 443
docker exec clab-management-access-ceos-probe-guest1 \
  nc -zvw 2 192.168.50.1 22
docker exec clab-management-access-ceos-probe-guest1 \
  nc -zvw 2 192.168.50.1 443
docker exec clab-management-access-ceos-probe-guest1 \
  ping -c 1 -W 2 192.168.50.1
docker exec clab-management-access-ceos-probe-device1 \
  Cli -p 15 -c "show ip access-lists MGMT-PLANE"
docker stats --no-stream \
  clab-management-access-ceos-probe-device1 \
  clab-management-access-ceos-probe-admin1 \
  clab-management-access-ceos-probe-guest1
```

The single-node probe deployed in about 23 seconds. Relevant output:

```text
SSHD status for Default VRF: enabled
HTTPS server: running, set to use port 443
HTTP server: shutdown, set to use port 80

admin1 TCP/22: open
admin1 TCP/443: open
guest1 TCP/22: Operation timed out
guest1 TCP/443: Operation timed out
guest1 ICMP: 0% packet loss

Configured on Ingress: control-plane(default VRF)
Active on     Ingress: control-plane(default VRF)
```

Each of the five intended ACL sequences reported non-zero packet counters.
The highest sampled cEOS memory was 1.19 GiB. In the full three-node probe,
cEOS used 1.158 GiB, `admin1` 1.09 MiB, and `guest1` 2.844 MiB
(about 1.162 GiB aggregate).

## Cleanup and repeatability

- Destroy command:
  `containerlab destroy -t /tmp/management-access-ceos-probe-019fb7/topology.clab.yml --cleanup`.
- Both disposable destroys removed matching containers, host entries, the SSH
  fragment, and the generated lab directory. The explicit temporary directory
  was then removed.
- The implemented lab was subsequently deployed from a clean state twice.
  Both runs reproduced the same service, ACL, counter, failure, repair, and
  cleanup behavior.

## Unsupported behavior and limitations

- TCP reachability and EOS service state were proven; an interactive SSH login
  and authenticated eAPI transaction were not required by this ACL lab and
  were not tested.
- cEOS uses its lab-generated HTTPS certificate. Production PKI, AAA, TLS
  hardening, and credential management are not claimed.
- The licensed cEOS image is version-pinned and recorded by local image ID; no
  redistributable digest or vulnerability-scanner result is claimed.
- The requested `lab-tutor` skill was unavailable. Student-flow review used
  `labs/AUTHORING.md` as the fallback contract.
