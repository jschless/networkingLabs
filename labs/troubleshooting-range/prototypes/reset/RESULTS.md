# Reset Prototype Results

Run `./reset.sh test` on the lab host before recording a result here. The test
is the authoritative assertion: all three node types must return to golden
state, the cEOS access port and FRR static route must return, and every
container's `StartedAt` timestamp must be unchanged.

## State that configuration replacement does not inherently reset

- ARP/ND and switch MAC tables age independently; a scenario reset must flush
  them when a fast, deterministic retry depends on them.
- Connection tracking survives a routing or firewall config reload; Linux
  service-node reset scripts must run `conntrack -F` when conntrack is present.
- Counters, logs, DHCP leases, and learned dynamic protocol state are runtime
  evidence, not configuration. Scenario clears must explicitly handle the
  relevant one; the health gate must not mistake stale evidence for success.

## 2026-07-12 validation — lab host

`./reset.sh test` passed on the 16 GiB lab host with ContainerLab 0.74.1,
`ceos:4.35.2F`, and `frr-lab:local`. It deployed the three-node topology,
verified its baseline, injected faults into all three node types, reset them,
verified the baseline again, and confirmed identical Docker `StartedAt`
timestamps for every node. The reset completed within the script's one-second
measurement resolution; deployment took roughly 25 seconds, dominated by cEOS
boot.

Two implementation decisions came from the test:

- cEOS configuration must be fed as an interactive command stream; repeated
  `Cli -c` invocations do not preserve configuration-submode state.
- FRR's source config is mounted read-only as `/etc/frr/frr.conf.orig`, then
  copied to writable `/etc/frr/frr.conf` before `frr-reload.py` runs. This
  preserves the no-source-mutation guarantee while allowing FRR to save its
  integrated configuration.
