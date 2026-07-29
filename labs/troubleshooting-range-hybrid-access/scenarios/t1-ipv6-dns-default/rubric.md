# Proctor rubric — TR-HA-103 (confidential)

**Root cause:** Router-advertisement acceptance is disabled at runtime on
`managed-client` (`net.ipv6.conf.eth1.accept_ra=0`). The healthy advertisement
from `campus-edge` still carries a nonzero default-router lifetime and the RDNSS
address `2001:db8:70:53::53`, but the client does not install the advertised
default. Its IPv6-only resolver therefore cannot reach the off-link DNS service.
IPv4, the authoritative DNS service, the cloud application, and upstream
forwarding policy are healthy.
**Pass threshold:** 70/100 and the scenario `verify.sh` must pass.
**Tier time band:** 20 minutes, provisional until a human blind pilot is recorded.

## Diagnostic decision path

1. Reproduce failed system name resolution and IPv6 application access from
   `managed-client`, then prove the IPv4 application path remains healthy.
2. Confirm the client retains its global IPv6 address and configured IPv6
   resolver but lacks an IPv6 default route.
3. Inspect the interface RA-acceptance setting and capture a live advertisement;
   distinguish a healthy nonzero router lifetime plus RDNSS option from the
   client's disabled acceptance state.
4. Enable RA acceptance only. Wait for the kernel to learn a `proto ra`
   link-local default; do not add a static route or replace DNS with IPv4.
5. Run `./range.sh verify` and record learned-route, AAAA-resolution, IPv6
   application, and negative protected-origin evidence.

## Weighted evidence milestones

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces DNS and IPv6 application failure while proving the IPv4 application remains healthy | 20 | −10 if only name resolution or the application is tested; −20 if scope is assumed |
| Shows the global IPv6 address and IPv6 resolver are present but the IPv6 default route is absent | 20 | −10 for checking only address or route; −20 for changing upstream routing without endpoint evidence |
| Finds `accept_ra=0` and captures the healthy advertisement's nonzero router lifetime plus RDNSS `2001:db8:70:53::53` | 30 | −15 if only the sysctl or packet evidence is collected; −30 for asserting the cause without direct evidence |
| Enables only interface RA acceptance and waits for a link-local `proto ra` default | 15 | −15 for a static default, IPv4 resolver, host entry, RA-server change, or unrelated network change |
| Runs the mandatory verifier and documents AAAA resolution, IPv6 application success, and retained protected-origin denial | 15 | −15 if the verifier is not run; −8 if negative validation is omitted |

Useful evidence commands:

```bash
./range.sh shell managed-client
ip -6 address show dev eth1
ip -6 route show
cat /etc/resolv.conf
dig +time=1 +tries=1 analytics.hybrid.test AAAA
python3 /opt/range/http_probe.py 2001:db8:70:41::40 8080 cloud-app-a-ok
python3 /opt/range/http_probe.py 10.70.41.40 8080 cloud-app-a-ok
sysctl net.ipv6.conf.eth1.accept_ra
timeout 10 tcpdump -ni eth1 -c 1 -vv 'icmp6 and ip6[40] == 134'
```

Minimal repair on `managed-client`:

```bash
sysctl -w net.ipv6.conf.eth1.accept_ra=1
```

Wait for the next advertisement, then confirm `ip -6 route show default`
reports a link-local gateway with `proto ra` before running the verifier.

Red flags: a static IPv6 default, an IPv4 resolver or IPv4-only proof, a
`/etc/hosts` override, changing the advertised router lifetime or RDNSS data,
flushing upstream policy, broad forwarding changes, service shutdown, or any
container restart caps the score at 69. Passing requires `./range.sh verify`;
IPv4 recovery or a manually installed route is insufficient.
