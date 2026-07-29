# Feature Probe Record — `troubleshooting-range-dci-edge`

## Scope and decision

- **Load-bearing feature:** cEOS runtime approved-prefix policy mutation, soft
  refresh, and golden `configure replace` recovery without a container restart.
- **Decision:** go; no fallback or rename.
- **Fidelity:** the exact cEOS image passed the new reset contract. The merged
  DCI source lab already proves four-node EVPN type-5 exchange and forwarding;
  this probe isolated the range-specific runtime mutation/reset mechanism.
- **Owner/date:** Codex, 2026-07-29 UTC.

## Environment

| Item | Exact value |
|---|---|
| Base commit | `bc55f69da95acae2f5b14964f1582bbf387777cb` |
| Host | Linux x86_64 `5.15.0-181-generic`; 15 GiB RAM, 13 GiB available; 139 GiB filesystem available |
| ContainerLab | 0.74.1, commit `1866b3a2b`, 2026-03-15 |
| Docker | client/server 29.5.3 |
| Host Python / Git | 3.10.12 / 2.34.1 |
| cEOS image | `ceos:4.35.2F`, `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`, 2,562,840,665 bytes |
| EOS | `4.35.2F-46221466.4352F (engineering build)` |

## Smallest load-bearing test

A disposable two-cEOS eBGP topology advertised `198.51.100.1/32` through an
inbound `APPROVED` prefix list. Baseline output showed the session Established
with one accepted prefix. The first CLI call incorrectly supplied configuration
lines as separate `Cli -c` arguments; only the last argument was applied, so the
route remained and the probe deliberately failed:

```text
FAULT_FAIL route still installed
```

The corrected command supplied one multiline CLI transaction:

```bash
docker exec clab-range-dci-edge-probe-edge Cli -p 15 -c \
  $'enable\nconfigure\nno ip prefix-list APPROVED\nip prefix-list APPROVED seq 10 permit 198.51.101.1/32\nend\nclear bgp * soft in'
```

Observed fault state:

```text
10.255.99.1 4 65001 ... Estab   1      0      0
ip prefix-list APPROVED seq 10 permit 198.51.101.1/32
FAULT_PASS approved peer prefix removed while BGP stays established
```

Golden recovery:

```bash
docker exec clab-range-dci-edge-probe-edge Cli -p 15 -c \
  $'enable\nconfigure replace flash:startup-config'
docker exec clab-range-dci-edge-probe-edge Cli -p 15 -c \
  $'enable\nclear bgp * soft in'
```

Result:

```text
reset_elapsed=0.62 reset_maxrss_kib=29588 reset_exit=0
edge_started=2026-07-29T09:27:28.789421106Z restarts=0
ip prefix-list APPROVED seq 10 permit 198.51.100.1/32
via 10.255.99.1, Ethernet1
PROBE_PASS runtime_policy_fault_golden_configure_replace_no_restart
```

The two cEOS containers used 1.225 and 1.235 GiB (2.460 GiB total). Deploy took
36.99 seconds with 43,084 KiB command RSS. Scoped destroy took 1.73 seconds,
removed both containers/host entries/SSH include, and left no probe network or
named link.

## Fallback and exclusions

No fallback or topology rename was needed. The range retains the source carrier
lab's already documented OVS userspace fallback and does not relabel it as
hardware QinQ/CFM. Probe artifacts were disposable and are not committed.
