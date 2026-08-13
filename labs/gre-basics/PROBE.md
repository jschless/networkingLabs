# gre-basics platform probe

## Decision

The learned gateways remain native Arista EOS using `ceos:4.35.2F`. GRE,
Tunnel0, and OSPF are the critical mechanisms; no Linux or FRR exception is
claimed for them. The two end hosts and routed transit are incidental
`ops-lab:local` Linux nodes with deterministic setup scripts and no routing
daemon. The lab is classified as **Build**.

## Main-observed legacy and platform evidence

This record preserves observations supplied by the main orchestrator from its
live platform investigation. It does not claim that the implementation worker
reran those commands.

| Area | Observed behavior |
|------|-------------------|
| Tunnel source syntax | `tunnel source interface EthernetN` was accepted; `tunnel source EthernetN` was rejected |
| Passive OSPF syntax | Interface command `ip ospf passive` was rejected; the LAN participates with `ip ospf area 0` and becomes passive using `passive-interface EthernetN` under `router ospf 1` |
| Outer GRE TTL | Without an override, an OSPF packet with inner TTL 1 was captured with outer GRE TTL 1 and expired at the Linux transit hop |
| Tunnel TTL sequence | `tunnel path-mtu-discovery` followed by `tunnel ttl 255` was the accepted working sequence |
| Tunnel route installation | Removing `tunnel routes` preserved a Full OSPF neighbor but removed the OSPF-learned LAN routes |
| OSPF network type | Default broadcast operation reached Full and elected DR/BDR; point-to-point is selected to eliminate the unnecessary election, not to repair a failed adjacency |
| Recursive endpoint fault | Adding `ip route 203.0.113.6/32 172.16.0.2` on `gw-a` left the interface text up while interface detail reported a recursive-resolution condition; traffic failed and OSPF aged out |
| Native tunnel device | The earlier checker expected Linux `tun0`; the observed kernel device was `tu0`. The remediated checker uses native EOS configuration/state instead of grading that implementation detail |
| cEOS forwarding rule | The original topology's one-shot `EOS_FORWARD` deletion could run before the rule existed. The accepted setup removes late insertions and requires 30 seconds of stable absence after CLI readiness before writing its marker |

## Limits

These observations apply to the repository's local `ceos:4.35.2F` image and
must not be generalized to every EOS release. Final live evidence is recorded
in [VALIDATION.md](VALIDATION.md). Read-only review and same-reviewer follow-up
are complete; the reviewer returned `No actionable findings remain`.
