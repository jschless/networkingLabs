# WP-14 — Advanced Network Security Architecture Capstone

## Outcome

Build `labs/advanced-security-architecture/`, an integration capstone spanning
internet edge, DMZ, protected applications, users, partners, remote access, identity
enforcement, NGFW/IPS visibility, WAF, DNS/egress control, management plane and
central logging. It should test whether the engineer can place controls in a coherent
architecture and prove that permitted paths cannot bypass them.

Target coverage: level 4. Prerequisites are the existing Security/SOC tracks plus
WP-06 zero trust, WP-07 peering, and preferably a completed OPNsense or FortiGate
platform lab.

## Platform and worktree gate

Before choosing the firewall:

1. Inspect the user's untracked `labs/opnsense-ngfw-basics/` work without modifying
   or deleting it. Ask/coordinate if it remains active.
2. Probe a reproducible, license-compatible OPNsense/other NGFW image for API/CLI
   automation, zones, NAT, HA if planned, IDS/IPS, URL/app controls available in the
   image, logging and clean overlay-disk teardown.
3. If no reproducible NGFW image works, use Linux nftables + Suricata + proxy/WAF
   components and name features accurately. Do not call port policy “application ID.”
4. Pin ModSecurity/Coraza or equivalent WAF and verify deterministic benign test cases.
5. Reuse zero-trust identity enforcement rather than duplicating its IdP lessons.

## Mandatory scope

Live where supported:

- zone/conduit and VRF segmentation across user, server, DMZ, partner, management;
- stateful firewall/NAT, rule ordering/shadowing and symmetric routing;
- IDS/IPS detection/block for safe lab signatures;
- WAF handling of benign OWASP-style test requests without exploitation guidance;
- DNS and egress proxy policy with explicit identity/source logging;
- remote/partner resource access through identity enforcement, not flat VPN trust;
- DDoS/route-security integration via rate limit and RTBH handoff from WP-07;
- centralized timestamps/logs and an incident evidence path;
- control-plane/OOB management separation and break-glass access.

Evidence/product mapping:

- TLS decryption governance/privacy, malware sandboxing, CASB/DLP, cloud-delivered
  SSE, vendor application databases and production threat feeds.

## Topology/addressing

```text
 internet/test -- edge -- ngfw -- core -- users
                         |  \-- protected-apps
                         |-- DMZ: reverse-proxy/WAF/public-app
                         |-- partner / ZTNA PEP
                         \-- management / logs / IDS
```

Use separate `/24`s under `10.114.0.0/16` for user, server, DMZ, partner,
management and security services, with `/30` routed transit. Public prefixes use
documentation ranges.

Prebuild routing, applications, identity foundation, logging, safe traffic cases and
management access. Withhold zone policy, NAT/publication, WAF/IPS rules, partner
policy, egress/DNS policy and log correlation.

## Student task sequence

1. **Guided data-flow and threat-model review:** turn business flows into a policy
   matrix; locate trust boundaries, control owners and fail-open/fail-closed decisions.
2. **Hinted zones/routing:** implement explicit inter-zone policy and return symmetry;
   protect management/OOB and preserve break-glass from its dedicated source only.
3. **Hinted publication:** publish the DMZ app through reverse proxy/WAF and exact NAT;
   prove origin cannot be reached directly and internal hairpin behavior is intentional.
4. **Hinted IDS/IPS:** mirror/inspect the intended path, trigger safe test signatures,
   distinguish alert-only from block, and verify false-positive rollback.
5. **Hinted egress/DNS:** allow approved destinations/categories/test domains, block
   direct resolver bypass and log user/source/destination decision.
6. **Hinted remote/partner access:** reuse identity/resource policy so partner reaches
   one application route, not the internal network.
7. **Hinted routing-security response:** accept a lab blackhole request through the
   approved control path and prove scope/expiry.
8. **Open policy review:** find shadowed/redundant/broad rules and produce a safer
   ordered policy with no service regression.
9. **Break-It:** a new broad allow rule above the inspection/NAT-specific policy lets
   one partner path bypass WAF/IPS to the origin. Normal public tests still pass.
   Diagnose from path/counters/log gaps, remove/reorder the shadowing rule, and prove
   origin-bypass denial plus intended partner/public access.

## Make the invisible visible

- Per-flow trace across routing, NAT, firewall, WAF/IPS and origin logs.
- Rule hit counters and shadow analysis.
- Independent origin-bypass tests from every external zone.
- Correlated event IDs/timestamps across controls.
- Clear distinction between routed reachability, stateful permit and application permit.

## Automated checks

`check.sh` must assert at minimum:

1. Every policy-matrix permit succeeds by intended path.
2. Every deny fails over IPv4 and IPv6 where the topology is dual-stack.
3. Public app is reachable only through WAF/reverse proxy.
4. Partner reaches one resource only.
5. Management reachable only from management/break-glass sources.
6. DNS bypass and unapproved egress fail/log.
7. Safe IDS test alerts; block-mode test blocks only scoped traffic.
8. WAF safe test generates intended action without breaking normal requests.
9. NAT/hairpin and return paths are symmetric.
10. RTBH affects only selected test prefix and clears/ages out.
11. All key permits/denies have correlated log evidence.
12. Shadow-rule Break-It fails independent bypass assertions.

## Planned files/docs

- Standard lab files, platform decision/probe, policy matrix, safe traffic tests,
  WAF/IDS rules, logging correlation script, `VALIDATION.md`.
- `docs/tracks/security/advanced-security-architecture.md`, with prerequisites
  across Security, SOC, BGP and zero trust.
- Licensed/optional components clearly identified in image docs.

## Resource target

- ≤ 9 GiB steady and ≤ 11 GiB peak; if the chosen NGFW alone prevents this, split
  the lab into edge-security and secure-access deployments rather than overcommit.

## Definition of done

All master gates apply. Complete a full policy-matrix walk, bypass testing from every
zone, safe IDS/WAF tests, management isolation, RTBH expiry, shadow-rule Break-It,
log correlation and clean redeploy. A second reviewer must examine security claims.
