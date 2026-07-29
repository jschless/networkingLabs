# Proctor rubric — TR-DE-301 (confidential)

**Root cause:** A stale sequence 5 in the `DCI-PROD` outbound route map on
`a-bgw` rejects Site A EVPN routes carrying the local PROD extended community
before export across the DCI. Local EVPN and the inter-site session stay healthy.
**Pass threshold:** 80/100 and the scenario `verify.sh` must pass.
**Tier time band:** 60 minutes, provisional until a human blind pilot is recorded.

## Diagnostic decision path

1. Compare each site's local application with Site B access to Site A applications.
2. Separate endpoint/service state, Site B PROD FIB, received inter-site EVPN,
   Site A local EVPN, and the border export boundary.
3. Inspect border policy order and identify the stale outbound deny sequence.
4. Remove only that sequence; refresh outbound policy.
5. Run `./range.sh verify` and document bidirectional routed recovery plus the
   absence of a static route or Layer-2 workaround.

## Weighted evidence milestones

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces remote Site A loss while proving both site-local applications healthy | 15 | −10 if only the failed request is tested |
| Shows the inter-site session and Site A local route are healthy but Site B's PROD FIB lacks the route | 25 | −5 per skipped plane; −20 for blaming the endpoint without evidence |
| Finds `DCI-PROD` sequence 5 denying the local PROD extended community at the Site A border | 25 | −12 if policy is named without the neighbor direction; −25 for guessing |
| Removes only the stale sequence, then performs a soft outbound refresh | 20 | −20 for a static VRF route, L2 stretch, broad permit, session restart, or unrelated policy change |
| Runs the mandatory verifier and records local, shared, inter-site, and negative architecture evidence | 15 | −15 if verifier is absent; −8 if workaround rejection is omitted |

Useful evidence commands:

```bash
./range.sh shell b-prod
python3 /opt/range/http_probe.py 172.16.10.10 8080 site-a-prod-ok
python3 /opt/range/http_probe.py 172.17.10.10 8080 site-b-prod-ok

./range.sh shell b-leaf
show ip route vrf PROD 172.16.10.0/24
show bgp evpn route-type ip-prefix

./range.sh shell a-bgw
show bgp evpn summary
show bgp evpn route-type ip-prefix
show route-map DCI-PROD
show running-config section router bgp
```

Minimal repair:

```text
configure
no route-map DCI-PROD deny 5
end
clear bgp * soft out
```

Red flags: static tenant routes, extending VLAN 10 across the DCI, broad policy
permits, disabling route policy, clearing the session hard, changing endpoints,
or restarting a container caps the score at 79. Passing requires
`./range.sh verify`; a recovered ping without control-plane and negative evidence
is not sufficient.
