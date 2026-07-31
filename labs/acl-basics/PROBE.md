# Feature Probe Record — `acl-basics`

## Scope and decision

- **Feature and learning objective:** prove that cEOS 4.35.2F can enforce a
  source-, destination-, protocol-, and port-aware IPv4 ACL on routed transit
  interfaces, expose per-entry first-match counters, and report the active
  interface attachment.
- **Decision:** go; use one cEOS router for the learned data-plane role and
  `ops-lab:local` only for the three incidental traffic endpoints.
- **Fidelity boundary:** this probe covers packets forwarded through the
  router. It is explicitly distinct from the router-local system control-plane
  behavior established by `management-access-control`.
- **Owner and date:** Codex, 2026-07-31.

## Environment

The host and image facts are the exact values recorded by the established
`management-access-control` environment probe on the same date.

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | client/server `29.5.3` |
| cEOS image | `ceos:4.35.2F`, image ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`, 2,562,840,665 bytes |
| Reported NOS | `4.35.2F-46221466.4352F (engineering build)` |
| Linux endpoint image | `ops-lab:local`, image ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, 68,762,000 bytes |
| Host before probe | 15 GiB RAM, 12 GiB available, 0 B of 2 GiB swap used; 139 GiB disk available |

## Smallest load-bearing test

The disposable files lived under
`/tmp/acl-basics-ceos-probe-019fb7` and were removed after the run. Exact
deployment and baseline commands were:

```bash
containerlab deploy \
  -t /tmp/acl-basics-ceos-probe-019fb7/topology.clab.yml
docker exec clab-acl-basics-ceos-probe-server \
  ss -lnt
docker exec clab-acl-basics-ceos-probe-client \
  ping -c 2 -W 2 192.168.30.10
docker exec clab-acl-basics-ceos-probe-client \
  nc -zvw 2 192.168.30.10 8080
docker exec clab-acl-basics-ceos-probe-client \
  nc -zvw 2 192.168.30.10 2222
docker exec clab-acl-basics-ceos-probe-attacker \
  ping -c 2 -W 2 192.168.30.10
docker exec clab-acl-basics-ceos-probe-attacker \
  nc -zvw 2 192.168.30.10 8080
docker exec clab-acl-basics-ceos-probe-attacker \
  nc -zvw 2 192.168.30.10 2222
```

The exact initial ACL lines and final sequence 45 are recorded below. They
were entered with non-interactive `Cli -p 15 -c` configuration calls. The
attachment fault and repair commands were:

```text
configure
interface Ethernet1
   no ip access-group TRANSIT-IN in
interface Ethernet2
   no ip access-group TRANSIT-IN in
interface Ethernet3
   ip access-group TRANSIT-IN in
end

configure
interface Ethernet3
   no ip access-group TRANSIT-IN in
interface Ethernet1
   ip access-group TRANSIT-IN in
interface Ethernet2
   ip access-group TRANSIT-IN in
end
```

Each stage repeated the relevant `ping` and `nc` probes, followed by:

```bash
docker exec clab-acl-basics-ceos-probe-router \
  Cli -p 15 -c "show ip access-lists TRANSIT-IN"
docker stats --no-stream \
  clab-acl-basics-ceos-probe-router \
  clab-acl-basics-ceos-probe-client \
  clab-acl-basics-ceos-probe-attacker \
  clab-acl-basics-ceos-probe-server
```

ContainerLab deployed the four nodes in about 26 seconds. The complete
deploy, baseline, policy, fault, repair, final exception, resource sample,
and cleanup sequence took about 2 minutes 46 seconds.

## Supplied live-probe evidence

The probe used a trusted source at `192.168.10.10/24` on Ethernet1, an
untrusted source at `192.168.20.10/24` on Ethernet2, and a downstream server
at `192.168.30.10/24` on Ethernet3 with TCP/8080 and TCP/2222 listeners.

The initial `TRANSIT-IN` policy accepted by cEOS used `counters per-entry`
and these sequences:

```text
10 permit icmp 192.168.10.0/24 host 192.168.30.10
20 permit tcp 192.168.10.0/24 host 192.168.30.10 eq 8080
30 deny tcp 192.168.10.0/24 host 192.168.30.10 eq 2222
40 permit icmp 192.168.20.0/24 host 192.168.30.10
50 deny tcp 192.168.20.0/24 host 192.168.30.10
60 permit ip any any
```

With the ACL inbound on Ethernet1 and Ethernet2, the supplied probe observed:

| Flow | Observed result |
|------|-----------------|
| client → server ICMP | Passed |
| client → server TCP/8080 | Passed |
| client → server TCP/2222 | Timed out |
| attacker → server ICMP | Passed |
| attacker → server TCP/8080 | Timed out |
| attacker → server TCP/2222 | Timed out |

Per-entry counters rendered as `[match N packets, ...]`. The attachment
summary rendered exactly:

```text
Configured on Ingress: Et1-2
Active on     Ingress: Et1-2
```

The fault probe moved the unchanged ACL to inbound Ethernet3. Client
TCP/2222 and attacker TCP/8080 then opened unexpectedly, the earlier decision
counters did not increase, sequence 60 counted server return traffic, and the
attachment output named `Et3`. Removing the Ethernet3 attachment and restoring
inbound Ethernet1 and Ethernet2 restored the initial outcomes.

The final change inserted this entry before sequence 50:

```text
45 permit tcp host 192.168.20.10 host 192.168.30.10 eq 2222
```

The supplied final probe observed all intended final flows passing their
permit/deny expectations, exactly seven rules, and attachment on `Et1-2`.

## Resource sample

| Node | Sampled memory |
|------|----------------|
| `router` | 1.115 GiB |
| `client` | 604 KiB |
| `attacker` | 620 KiB |
| `server` | 23.65 MiB |

The sampled aggregate was approximately 1.14 GiB.

## Cleanup and repeatability

```bash
containerlab destroy \
  -t /tmp/acl-basics-ceos-probe-019fb7/topology.clab.yml --cleanup
rm -rf /tmp/acl-basics-ceos-probe-019fb7
docker ps --format '{{.Names}}' | \
  grep '^clab-acl-basics-ceos-probe-'
```

The scoped destroy removed all four containers, host entries, SSH fragment,
and generated lab directory. The final matching-container command returned no
lines, and the explicit temporary directory was absent after removal.

Repeatability was proven with the implemented target: a later clean deploy of
the same four-node roles reproduced the baseline, six-rule policy, counter
evidence, wrong-interface fault, repair, seven-rule final policy, and clean
destroy. The final target checker passed 31/31 twice.

## Boundaries and limitations

- The record carries forward exact environment identity from the established
  probe and records only the supplied ACL workflow observations above.
- TCP connect behavior and listener health were in scope; application
  transactions, authentication, TLS, and payload inspection were not.
- IPv6 ACLs, fragments, logging, ACL scale, reload persistence, and production
  hardware forwarding behavior were not probed.
- This record documents the feature decision. The separate clean final-target
  walk and repository gates are recorded in `VALIDATION.md`.
