# qos-enterprise platform probe

## Decision

The learned router uses native VyOS (`kind: vyosnetworks_vyos`,
`image: vyos:local`). The four generators/receivers are incidental Linux nodes
using the purpose-built `qos-lab:local` image. The lab is a **Build** lab.

No cEOS exception is claimed: VyOS passed the required native feature probe, so
another router platform was not needed. VyOS owns the learned `qos` configuration
and renders a real software scheduler through Linux `tc`.

## Probe environment

| Item | Observed value |
|------|----------------|
| VyOS image | `vyos:local` |
| Image ID | `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495` |
| Architecture / size | amd64 / 2,264,851,359 bytes |
| NOS release | VyOS `2026.03.15-0031-rolling` |
| Build commit | `96ff51d3d2e559` |
| Probe topology | One Linux source, one native VyOS router, one Linux destination |
| Clean deploy | 15.46 seconds; runner maximum RSS 41,728 KiB |
| Memory sample | source 4.684 MiB; VyOS 255.8 MiB; destination 5.434 MiB |
| Clean destroy | 1.24 seconds; no residual containers, network, or generated directory |

## Native feature evidence

Current `set qos policy shaper ...` commands and
`set qos interface eth2 egress QOS-PROBE` committed successfully. VyOS rendered:

- an HTB root at 2 Mbit/s;
- class 10 at 800 kbit/s, class 20 at 600 kbit/s, and default at 600 kbit/s;
- u32 matches for ECN-zero EF (`0xb8`) and AF41 (`0x88`), each with an
  admission policer and `action reclassify`;
- PFIFO, RED, and SFQ leaves; and
- real filter, class, and root packet/byte/drop counters.

With concurrent 500 kbit/s EF, 1 Mbit/s AF41, and 4 Mbit/s BE UDP offers, the
probe observed 0% EF loss at 499,997 offered bit/s, 44.64% AF41 loss, and 73.52%
BE loss. Root counters reached 3,290,880 bytes and 2,701 packets. These are
probe observations, not exact performance guarantees.

A separate native `rate-control` policy at 2 Mbit/s rendered a TBF baseline.
The same 5.5 Mbit/s offer observed 100% EF loss, 89.36% AF41 loss, 60.88% BE
loss, and 4,801 TBF drops. The baseline therefore proves aggregate shaping but
does not provide DSCP-aware scheduling.

The observed renderer adds an 800 Kbit/s admission policer to the EF u32 rule
and a 600 Kbit/s policer to the AF41 rule. Conforming packets are directed to
their explicit classes; `action reclassify` lets excess continue toward the
default path. Under the 1 Mbit/s AF41 offer, class `1:14` showed no new borrowed
packets while default `1:15` borrowed. A configured 2 Mbit/s class-20 ceiling
therefore establishes borrowing eligibility, not proof that this matched flow
borrows.

The final lab intentionally changes the probe queue treatments: voice uses
drop-tail with no explicitly configured ceiling, leaving its effective ceiling
at 800 kbit/s; video uses SFQ with a 2 Mbit/s ceiling; and unmatched bulk uses
RED with a 2 Mbit/s ceiling. HTB priority matters only among traffic actually
queued in eligible classes and is never described as absolute strict priority.

The observed u32 mask was `00ff0000`, which matches the complete ToS byte. The
probe validated only ECN-zero `0xb8` and `0x88`; it does not establish that
ECN-marked variants match the same explicit rules.

## Sources and limits

The current [VyOS Traffic Policy documentation](https://docs.vyos.io/en/rolling/configuration/trafficpolicy/index.html)
documents Shaper as HTB and the `qos interface ... egress` attachment model.
The probe validates the local rolling image above; other builds must be
revalidated. This is software scheduling, not Cisco MQC or hardware queueing.
