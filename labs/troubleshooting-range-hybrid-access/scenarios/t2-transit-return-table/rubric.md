# Proctor rubric — TR-HA-201 (confidential)

**Root cause:** The managed-client IPv4 and IPv6 prefixes on `cloud-edge` are
associated with a lower-metric blackhole return table instead of the intended
WAN A preferred and WAN B standby transit returns. The valid forward and
return routes remain installed, so campus route lookup and hosted-side service
health appear normal while all replies to `managed-client` are discarded.
**Pass threshold:** 70/100 and the scenario `verify.sh` must pass.
**Tier time band:** 35 minutes, provisional until a human blind pilot is recorded.

## Diagnostic decision path

1. Reproduce the IPv4 and IPv6 application timeouts from `managed-client`, then
   prove the same services are locally healthy from `cloud-edge`.
2. Confirm `campus-edge` selects WAN A for both application prefixes and use a
   packet capture or counters to separate outbound request arrival from absent
   replies.
3. Inspect the `cloud-edge` return lookup and full main tables for both
   managed-client prefixes. Distinguish the lower-metric blackholes from the
   retained WAN A metric-10 and WAN B metric-100 routes.
4. Delete only the two erroneous blackhole returns. Do not add client host
   routes, replace the prefix routes, alter WAN preference, or change policy.
5. Run `./range.sh verify` and record restored dual-stack services, both
   prefix-level transit returns, identity decisions, and direct-origin denial.

## Weighted evidence milestones

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces both application timeouts and proves the same hosted services are locally healthy | 15 | −8 if only one address family is tested; −15 if service failure is assumed |
| Proves WAN A remains the selected forward path and captures requests arriving without replies returning | 20 | −10 if only route presence is shown; −20 for changing the forward path without evidence |
| Finds both lower-metric blackhole returns ahead of the retained preferred and standby prefix routes | 30 | −15 if only one table is inspected; −30 for asserting policy or service cause without return evidence |
| Deletes only the two blackhole returns and preserves both prefix-level transit routes | 20 | −20 for a `/32` or `/128` client route, replacing the prefix routes, changing metrics, flushing routes, or an unrelated repair |
| Runs the mandatory verifier and documents dual-stack recovery plus retained identity and origin policy | 15 | −15 if the verifier is not run; −8 if negative architecture evidence is omitted |

Useful evidence commands:

```bash
./range.sh shell managed-client
python3 /opt/range/http_probe.py 10.70.41.40 8080 cloud-app-a-ok
python3 /opt/range/http_probe.py 2001:db8:70:41::40 8080 cloud-app-a-ok

./range.sh shell campus-edge
ip route get 10.70.41.40
ip -6 route get 2001:db8:70:41::40

./range.sh shell cloud-edge
wget -qO- http://10.70.41.40:8080/
wget -qO- 'http://[2001:db8:70:41::40]:8080/'
ip route get 10.70.10.10
ip -6 route get 2001:db8:70:10::10
ip route show exact 10.70.10.0/24
ip -6 route show exact 2001:db8:70:10::/64
```

Minimal repair on `cloud-edge`:

```bash
ip route del blackhole 10.70.10.0/24 metric 5
ip -6 route del blackhole 2001:db8:70:10::/64 metric 5
```

Red flags: adding a `/32` or `/128` route for the affected workstation,
replacing either managed prefix route with a single next hop, changing WAN
metrics, flushing a route table, changing forwarding policy, restarting a
service, or restarting a container caps the score at 69. Passing requires
`./range.sh verify`; restored application probes alone are insufficient.
