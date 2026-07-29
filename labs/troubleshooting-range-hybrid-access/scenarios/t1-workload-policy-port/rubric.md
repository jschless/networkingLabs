# Proctor rubric — TR-HA-101 (confidential)

**Root cause:** A runtime cloud workload-policy rule on `cloud-edge` rejects
TCP/8080 from the managed-client prefix to `origin-a` in both address families.
Routing, DNS, the health endpoint, the protected PEP path, and site B are healthy.
**Pass threshold:** 70/100 and the scenario `verify.sh` must pass.
**Tier time band:** 20 minutes, provisional until a human blind pilot is recorded.

## Diagnostic decision path

1. Reproduce from `managed-client`, then compare the same destination's health
   endpoint and the site-B application.
2. Confirm A/AAAA resolution and IPv4/IPv6 forwarding before inspecting policy.
3. Inspect ordered runtime forwarding policy on `cloud-edge`.
4. Remove only the two marked rejects; do not open the full client or cloud subnet.
5. Run `./range.sh verify` and record positive and negative evidence.

## Weighted evidence milestones

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces the analytics failure and bounds it against the healthy endpoint and site B | 20 | −10 if only one request is tested; −20 if scope is assumed |
| Proves A/AAAA answers and both routed paths are healthy | 15 | −10 if the engineer changes routing without evidence |
| Finds the two `range-t1-workload-port` ordered rejects with `iptables -S FORWARD` and `ip6tables -S FORWARD` | 30 | −15 for identifying only one address family; −30 for guessing |
| Removes only the two rejecting rules | 20 | −20 for a broad subnet allow, default-accept policy, flush, or unrelated change |
| Runs the mandatory verifier and documents restored application plus retained origin denial | 15 | −15 if the verifier is not run; −8 if negative policy is omitted from the write-up |

Useful evidence commands:

```bash
./range.sh shell managed-client
python3 /opt/range/http_probe.py 10.70.41.40 8080 cloud-app-a-ok
python3 /opt/range/http_probe.py 10.70.41.40 8081 cloud-health-a-ok
dig +short @10.70.53.53 analytics.hybrid.test A
ip route get 10.70.41.40

./range.sh shell cloud-edge
iptables -S FORWARD
ip6tables -S FORWARD
```

Minimal repair:

```bash
iptables -D FORWARD -s 10.70.10.0/24 -d 10.70.41.40 -p tcp --dport 8080 -m comment --comment range-t1-workload-port -j REJECT
ip6tables -D FORWARD -s 2001:db8:70:10::/64 -d 2001:db8:70:41::40 -p tcp --dport 8080 -m comment --comment range-t1-workload-port -j REJECT
```

Red flags: a full ruleset flush, default-accept forwarding, broad subnet allow,
application restart, static host entry, unrelated route, or container restart
caps the score at 69. Passing requires `./range.sh verify`; apparent browser
recovery alone is not sufficient.
