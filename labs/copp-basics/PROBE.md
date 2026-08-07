# Feature Probe Record — `copp-basics`

## Scope and platform decision

- **Learned feature:** software control-plane classification, token-bucket
  policing, ordered attachment, counters, and the Linux `INPUT` versus
  `FORWARD` boundary while FRR runs BGP and OSPF.
- **Decision:** use the repository-owned `copp-lab:local` image on r2 under a
  critical-role exception. r1 and r3 use the same image as incidental routing
  peers. This is a Linux/FRR reference, not hardware or ASIC CoPP.
- **Owner/date:** Codex probe and implementation pass, 2026-08-07.

## NOS probes and limits

The smallest load-bearing cEOS 4.35.2F probe entered configuration mode and
attempted `class-map type copp`. The CLI rejected the `copp` form as
unsupported, so cEOS could not implement the lab's required class/policy
surface on this image. No cEOS CoPP state is claimed.

The VyOS 2026.03.15 rolling probe parsed local `INPUT` limit rules, but the
firewall commit failed because required bridge netfilter sysctls were absent
in that container. A parsed candidate that cannot commit is not a viable lab
platform; no VyOS enforcement result is claimed.

## Selected FRR/Linux probe

The selected image is built with:

```text
docker build -t copp-lab:local labs/copp-basics/
```

| Item | Exact value |
|---|---|
| External base | `quay.io/frrouting/frr@sha256:fc7f887ab4d8da06f481a4f8d59afded88b3c5823f03610a7e808f7eba45eeea` |
| FRR / distribution | FRR 10.5.0; Alpine 3.22.2 |
| Corrected image | `sha256:643136a822877f72eae64f1c0808a873910fc6d371bebda2bf21f5c16063284f`; amd64; 197,231,555 bytes; `CMD ["sleep", "infinity"]` |
| Corrected cached build sample | 0.26 seconds; command max RSS 52,844 KiB |
| Added/refreshed pins | busybox `1.37.0-r20`, c-ares `1.34.8-r0`, iptables `1.8.11-r1`, musl `1.2.5-r12`, zlib `1.3.2-r0` |

A transient container from the same package/root-filesystem layers, with only
`NET_ADMIN` and `NET_RAW`, created `COPP` and
`COPP-ICMP`, attached one first-position `INPUT` jump, and applied an ICMP
limit of 2 packets/second with burst 4 followed by `DROP`. A bounded 20-packet
loopback burst produced 4 accepts and 16 drops. `iptables-save` reproduced the
attachment, dispatcher, rate, and drop rules. The container was run with
`--rm`; no probe container or rule state remained.

This proves the selected kernel/userspace path and counter mechanism.

## Startup ownership correction

The first main deploy exposed a deterministic ownership race: the inherited
FRR image command ran `docker-start` and its config load while ContainerLab's
`exec` also ran `setup.sh` and `vtysh -b`. r3 blocked on the duplicate load;
the deploy was interrupted after 80 seconds and destroyed cleanly.

The corrected image idles with `sleep infinity`. The setup script now waits
boundedly for every required data link, starts FRR once with `frrinit.sh`,
waits boundedly for all required daemon sockets plus a working vtysh session,
and invokes `vtysh -b` exactly once.

The corrected topology then deployed cleanly in 3.53 seconds with command max
RSS 41,104 KiB. All three nodes loaded deterministically with exact addresses,
reciprocal BGP Established and OSPF Full state, and bidirectional r1/r3
loopback transit. The complete policy, bounded positive/negative traffic,
break/repair, atomic negative, repeatability, point-memory, and cleanup
evidence is recorded in `VALIDATION.md`.
