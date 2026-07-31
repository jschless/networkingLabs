# Feature Probe Record — `urpf-antispoofing`

## Scope and decision

- **Learning objective:** enforce IPv4 source validation on a routed NOS,
  distinguish strict and loose reverse-path tests with one-way capture, and
  expose their live drop counters.
- **Decision:** go with VyOS for the learned edge role. Use
  `ops-lab:local` only for the two incidental traffic endpoints.
- **Platform order:** cEOS 4.35.2F was tested first and rejected only after
  its local data-plane CLI reported the feature unavailable. VyOS was then
  tested in the three-node data path and enforced the behavior.
- **Owner and date:** Codex, 2026-07-31.

## Environment

| Item | Exact value |
|------|-------------|
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | client/server `29.5.3` |
| cEOS candidate | `ceos:4.35.2F`, image ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`; NOS reported `4.35.2F-46221466.4352F (engineering build)` |
| Selected VyOS image | `vyos:local`, image ID `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495` |
| Reported VyOS | `2026.03.15-0031-rolling`; build UUID `d26b303c-df41-45ac-831e-3ebc174a407b`; commit `96ff51d3d2e559` |
| Linux endpoints | `ops-lab:local`, image ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7` |

## cEOS no-go evidence

A single cEOS edge was started first. In interface configuration mode the
load-bearing CLI query was:

```text
configure
interface Ethernet1
ip verify unicast source reachable-via ?
```

The local 4.35.2F image returned:

```text
% Unavailable command (not supported on this hardware platform)
```

That is a platform-specific data-plane limitation of this container image;
it is not evidence that EOS hardware platforms lack uRPF. No Linux routing
substitute was used to make a cEOS-labelled lab appear to support the
feature.

## Smallest VyOS test

The live probe used this three-node data plane:

| Node | Proven state |
|------|--------------|
| `attacker` | eth1 `10.10.1.1/30`; lo `10.0.0.10/32`, `10.99.99.1/32`, and `10.88.88.1/32`; default via `10.10.1.2` |
| `edge` | VyOS eth1 `10.10.1.2/30`; eth2 `10.10.2.1/30`; initial static `10.0.0.10/32` via `10.10.1.1` |
| `internet` | eth1 `10.10.2.2/30`; default via `10.10.2.1` |

ContainerLab's management default initially shared the main FIB. The probe
therefore committed the following isolation before interpreting any source
lookup:

```text
set vrf name MGMT table 100
set interfaces ethernet eth0 vrf MGMT
set vrf name MGMT protocols static route 0.0.0.0/0 next-hop 172.20.20.1
```

After commit, `ip route show table main` contained only the connected data
subnets and `10.0.0.10/32 via 10.10.1.1 dev eth1` before experiments. `ip
route show table 100` contained the management default via
`172.20.20.1 dev eth0` plus management connected/local routes.

The exact feature configurations tested were:

```text
set interfaces ethernet eth1 ip source-validation strict
set interfaces ethernet eth1 ip source-validation loose
```

Each mode was committed separately. Packets were generated with an explicit
source, and spoof forwarding was judged from a bounded capture on the
internet-facing link rather than from ping return status. Representative
commands were:

```bash
docker exec clab-urpf-ceos-probe-attacker \
  ping -c 2 -W 1 -I 10.0.0.10 10.10.2.2
docker exec clab-urpf-ceos-probe-attacker \
  ping -c 2 -W 1 -I 10.99.99.1 10.10.2.2
docker exec clab-urpf-ceos-probe-internet \
  timeout 4 tcpdump -lnni eth1 -c 1 \
  'icmp[icmptype] == icmp-echo and src host 10.99.99.1'
docker exec clab-urpf-ceos-probe-edge \
  nft list chain ip raw vyos_rpfilter
```

The temporary probe topology retained its original disposable topology name
while the selected edge image was changed from cEOS to VyOS; the container
names above therefore include `urpf-ceos-probe`.

## Supplied live results

| Mode and routing state | Source packet | Downstream observation |
|------------------------|---------------|------------------------|
| Strict, `10.0.0.10/32` via eth1 | legitimate `10.0.0.10` | Passed; ping to `10.10.2.2` succeeded |
| Strict, no `10.99.99.0/24` route | `10.99.99.1` | Dropped |
| Strict, `10.99.99.0/24` via eth2 | `10.99.99.1` arrives on eth1 | Dropped because reverse interface differed |
| Loose, `10.99.99.0/24` via eth2 | same `10.99.99.1` packet | Forwarded because the source was reachable |
| Loose, no main default | unrouted `10.88.88.1` | Dropped |
| Loose, main default via `10.10.2.2` | same `10.88.88.1` packet | Forwarded because the default satisfied reachability |

The platform probe did not capture a source-validation-disabled baseline.
That observation is part of the implemented lab's pending clean target walk,
not supplied probe evidence.

Strict mode rendered this rule and return path in the live nftables chain:

```text
iifname "eth1" fib saddr . iif oif 0 counter packets 2 bytes 168 drop
iifname "eth1" counter packets 3 bytes 252 return
```

Loose mode rendered:

```text
iifname "eth1" fib saddr oif 0 counter packets 1 bytes 84 drop
iifname "eth1" counter packets 1 bytes 84 return
```

The relevant counter increased for fresh rejected packets in each mode.
These kernel rules show the mechanism: strict compares the source lookup's
output interface with the packet ingress; loose requires only a resolving
output.

## Resource sample

| Node | Sampled memory |
|------|----------------|
| `edge` | 397.3 MiB |
| `attacker` | 612 KiB |
| `internet` | 1.379 MiB |

The sampled aggregate was approximately 399.3 MiB.

## Cleanup and repeatability boundary

The disposable probe was destroyed with scoped ContainerLab cleanup and no
matching probe containers were left running:

```bash
containerlab destroy \
  -t /home/joe/containerlab/.tmp-urpf-probe/topology.clab.yml --cleanup
docker ps --format '{{.Names}}' | grep '^clab-urpf-ceos-probe-'
```

This record establishes the feature/platform decision and supplied behavior.
The separate implemented-target deploy, full task walk, fault rejection,
repair, checker result, resource high-water mark, and final destroy belong in
`VALIDATION.md` after they have actually been run.

## Boundaries and limitations

- The probe exercised IPv4 unicast source validation on one VyOS Ethernet
  ingress in a software-forwarded container. IPv6, ECMP, policy routing,
  multiple VRFs for production data, fragments, scale, and physical hardware
  forwarding were not tested.
- One-way capture is authoritative only for the sampled request on the
  downstream link. It does not establish application availability.
- A default route can weaken loose uRPF in the tested main table. The result
  should not be generalized across NOSes without a local probe because some
  platforms expose an explicit allow-default control.
- The requested `lab-tutor` skill was unavailable, so no tutor validation is
  claimed. The lab follows the repository authoring contract instead.
