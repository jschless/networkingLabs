# Feature Probe Record — `mtu-pmtud-troubleshooting`

## Scope and decision

- **Learning objective:** diagnose a real PMTUD feedback black hole across a
  GRE service, calculate the encapsulation budget, and repair the learned
  router roles with native NOS configuration.
- **Decision:** use VyOS for both learned edges and `ops-lab:local` Linux only
  for incidental hosts and provider scaffolding. The live multi-node probe
  established the exact VyOS GRE and tunnel-MTU behavior below.
- **Critical-role boundary:** `edge-a` and `edge-b` own GRE, routing, and the
  repair. Linux does not substitute for either learned router role.
- **Owner and date:** Codex, 2026-07-31.

## Environment

| Item | Exact value |
|------|-------------|
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | client/server `29.5.3` |
| Selected VyOS image | `vyos:local`, image ID `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495` |
| Reported VyOS | `2026.03.15-0031-rolling`; build UUID `d26b303c-df41-45ac-831e-3ebc174a407b`; commit `96ff51d3d2e559` |
| Linux scaffolding | `ops-lab:local`, with no additional packages required for this lab |

The disposable probe lived under `.tmp-mtu-probe`. It was destroyed after
the observations. Commands below use logical placeholders such as
`<edge-a>` and `<host-a>` normalized from that disposable topology; they do
not invent or preserve a removed container prefix.

## Smallest multi-node test

The live path was:

```text
host-a -- edge-a (VyOS) -- provider -- edge-b (VyOS) -- host-b
```

The two site links and both VyOS physical interfaces used MTU 1500. Both
provider data interfaces used MTU 1400. VyOS built native `tun0` interfaces
with `encapsulation gre`, addresses `172.16.0.1/30` and `172.16.0.2/30`, and
exact WAN source/remote pairs. Static transport and remote-LAN routes made
the underlay and overlay reachable.

The provider enabled IPv4 forwarding and installed one idempotent rule:

```bash
docker exec <provider> iptables -A OUTPUT -p icmp \
  --icmp-type fragmentation-needed -j DROP
```

The implemented target adds a stable comment to the same rule for checker
parsing. The rule remains installed in the solved state; the learned repair
does not remove or bypass provider policy.

## Probe actions

The platform and initial interface state were inspected with these
normalized operations:

```bash
docker image inspect vyos:local --format '{{.Id}}'
docker exec <edge-a> /bin/vbash -ic 'show version'
docker exec <edge-a> ip -o link show tun0
docker exec <edge-a> ip route show 192.168.2.0/24
docker exec <edge-a> ping -c 3 203.0.113.6
docker exec <host-a> ping -c 3 192.168.2.10
```

The default rendered operational `tun0` MTU was 1476. GRE underlay
reachability and small cross-site ping both passed.

One connected UDP socket forced IPv4 PMTU discovery to `DO`, sent one
datagram, waited up to three seconds, and validated an `ack:<payload>` reply.
The equivalent implemented-target commands are:

```bash
docker exec <host-a> /df-probe.py 1348 192.168.2.10
docker exec <host-a> /df-probe.py 1349 192.168.2.10
```

For the failing candidate, bounded captures ran on the named interfaces:

```bash
docker exec <edge-a> timeout 6 tcpdump -lnni eth2 -vv \
  -c 1 'proto gre'
docker exec <provider> timeout 6 tcpdump -lnni eth1 -vv \
  -c 1 'proto gre'
docker exec <host-a> timeout 6 tcpdump -lnni eth1 -vv \
  -c 1 'icmp[0] == 3 and icmp[1] == 4'
docker exec <provider> iptables -nvx -L OUTPUT
```

The service test requested exactly 262,144 bytes with an outer bound:

```bash
docker exec <host-a> timeout 8 python3 -c \
  "import urllib.request; print(len(urllib.request.urlopen('http://192.168.2.10:8080').read()))"
```

## Supplied live results

| State | Probe | Observed result |
|-------|-------|-----------------|
| Default VyOS `tun0` MTU 1476 | Small cross-site ping | Passed |
| Default state | DF UDP payload 1348 | `ack:1348` |
| Default state | DF UDP payload 1349 | Timed out after the bound |
| Default state | 1349 capture on `edge-a:eth2` and `provider:eth1` | Outer IPv4 GRE length 1401 with DF set, carrying inner IPv4 length 1377 and UDP payload 1349 |
| Default state | Host-side type 3/code 4 capture | No packet observed |
| Default state | Provider OUTPUT drop counter | Increased from 0 to 1 for the fresh failing probe |
| Default state | 256 KiB HTTP fetch | Timed out; `timeout` returned 143 |
| Both VyOS tunnels configured MTU 1376 | 256 KiB HTTP fetch | Completed; return code 0 |
| Fixed state after host route-cache flush | DF UDP payload 1349 | Local `EMSGSIZE`; host capture showed `192.168.1.1 > 192.168.1.10: ICMP ... need to frag (mtu 1376)` |
| Fixed state | DF UDP payload 1348 in both directions | `ack:1348` in both directions |
| Fixed state | Provider OUTPUT drop counter | Did not increase during final probes |
| One-sided `edge-b` `tun0` MTU 1300 | A-to-B payload 1348 | Still returned `ack:1348` |
| One-sided `edge-b` `tun0` MTU 1300 | B-to-A payload 1348 | Returned `EMSGSIZE` |
| `edge-b` restored to MTU 1376 | B-to-A payload 1348 | Returned `ack:1348` again |

The exact native repair committed on both VyOS devices was:

```text
configure
set interfaces tunnel tun0 mtu 1376
commit
```

The result follows the measured header budget: a 1,348-byte UDP payload plus
8-byte UDP and 20-byte inner IPv4 headers is a 1,376-byte inner packet. Base
IPv4 GRE adds 24 bytes, producing a 1,400-byte outer packet. One additional
payload byte produces outer length 1,401.

## Resource and timing sample

| Node | Sampled memory |
|------|----------------|
| `edge-a` | 250.5 MiB |
| `edge-b` | 255.9 MiB |
| `host-a` | 4.941 MiB |
| `host-b` | 13.95 MiB |
| `provider` | 660 KiB |

The sampled aggregate was approximately 526 MiB. Deployment took about 20
seconds in the supplied probe environment.

## Cleanup and repeatability boundary

The `.tmp-mtu-probe` topology was destroyed with scoped ContainerLab cleanup.
The removed topology directory and generated lab state were not retained,
and no matching probe containers remained. The observations above establish
the platform and mechanism. A separate clean deployment of the checked-in
target, full learner walk, negative checker run, repair, and final destroy
must be recorded in `VALIDATION.md` by the main validator.

## Boundaries and limitations

- This probe exercised IPv4, base IPv4 GRE, static routing, and software
  forwarding in one local VyOS rolling image. IPv6, GRE keys/options, IPsec,
  ECMP, policy routing, fragments, scale, and physical forwarding hardware
  were not tested.
- The provider policy is deliberate incident scaffolding. It does not
  replace routing or tunnel behavior on the learned VyOS roles.
- One UDP datagram and interface-specific captures support the exact size
  conclusions. TCP capture sizes on container veths can be distorted by
  GRO/GSO and are not used as authoritative packet-budget evidence.
- A timeout proves only that a transaction did not finish within the bound.
  The interface captures and counter delta establish the drop mechanism.
- The requested `lab-tutor` skill was unavailable, so no tutor validation is
  claimed. The implementation follows `labs/AUTHORING.md` instead.
