# Proctor rubric — TR-HA-104 (confidential)

**Root cause:** An earlier runtime ACL on `cloud-edge` rejects the GSLB
controller's health probe from `10.70.53.53` to the site-B health endpoint
`10.70.42.40:8081`. The exact source-limited probe allow remains present behind
the reject. Site B, its client-facing path, both WAN transports, and the
health-driven DNS publisher are healthy; the controller therefore marks only
site B down and withdraws both of its global A/AAAA answers.
**Pass threshold:** 70/100 and the scenario `verify.sh` must pass.
**Tier time band:** 20 minutes, provisional until a human blind pilot is recorded.

## Diagnostic decision path

1. Reproduce the one-site global answer set from `managed-client`, then prove
   both site-B application and health endpoints remain reachable directly.
2. Inspect the GSLB runtime state on `dns` and run its source-bound probe check;
   distinguish the failed site-B probe from the healthy site-A probe.
3. Confirm the route from the probe source, then inspect ordered runtime policy
   on `cloud-edge`; find the site-B reject before the two narrow probe permits.
4. Remove only the marked site-B reject. Do not force an answer, change the
   controller, widen the probe source, or alter default-deny policy.
5. Wait for the next health cycle, run `./range.sh verify`, and record fresh
   probe evidence, both dynamic A/AAAA site answers, and retained negative
   origin policy.

## Weighted evidence milestones

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces the primary-only A/AAAA results and bounds them against the healthy site-B regional application and health endpoint | 20 | −10 if only the global answer or direct site is checked; −20 if scope is assumed |
| Reads `/run/range-t1-gslb-state.env` and runs the controller's `--probe-only` check to show site A healthy, site B down, and probe source `10.70.53.53` | 25 | −12 if health state or source evidence is missing; −25 for asserting a cause without controller evidence |
| Finds `range-t1-gslb-probe-deny` ordered ahead of the two exact source-limited health permits on `cloud-edge` | 25 | −12 if rule order or the retained permits are not shown; −25 for changing application or WAN state without policy evidence |
| Removes only the marked site-B reject and waits for health-driven republishing | 15 | −15 for a static answer, host override, broad source/destination allow, policy flush, controller change, or unrelated repair |
| Runs the mandatory verifier and documents fresh probe success, both dynamic A/AAAA sites, and retained direct-origin denial | 15 | −15 if the verifier is not run; −8 if dynamic or negative evidence is omitted |

Useful evidence commands:

```bash
./range.sh shell managed-client
dig +short @10.70.53.53 global.hybrid.test A
dig +short @2001:db8:70:53::53 global.hybrid.test AAAA
python3 /opt/range/http_probe.py 10.70.42.40 8080 cloud-app-b-ok
python3 /opt/range/http_probe.py 10.70.42.40 8081 cloud-health-b-ok

./range.sh shell dns
cat /run/range-t1-gslb-state.env
python3 /run/range-t1-gslb-controller.py --probe-only
ip route get 10.70.42.40 from 10.70.53.53

./range.sh shell cloud-edge
iptables -S FORWARD
```

Minimal repair on `cloud-edge`:

```bash
iptables -D FORWARD -s 10.70.53.53 -d 10.70.42.40 -p tcp --dport 8081 -m comment --comment range-t1-gslb-probe-deny -j REJECT
```

Wait for `/run/range-t1-gslb-state.env` to report both sites healthy before
running the verifier. This is a provider-neutral health-driven DNS/GSLB model;
the IPv4 source-bound health result controls both address families' site
answers and does not claim a production Internet GSLB control plane.

Red flags: forcing a static DNS answer, adding a `/etc/hosts` entry, disabling
health evaluation, widening the probe ACL, changing default-deny forwarding,
flushing policy, shutting down a service, altering application/WAN state, or
restarting a container caps the score at 69. Passing requires
`./range.sh verify`; seeing both addresses alone is insufficient.
