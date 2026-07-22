# WP-06 — Zero-Trust Secure Access

## Outcome

Build `labs/zero-trust-secure-access/`, a practice lab demonstrating resource-centric,
identity- and device-aware access from remote and internal clients. A policy
enforcement proxy should authenticate users through OIDC, require a lab device
credential where appropriate, authorize by group/resource, prevent origin bypass,
and produce an auditable decision trail.

Target coverage: level 4. This is a ZTNA mechanism lab, not a claim to reproduce a
commercial global SASE service.

## Fidelity and reuse

Prefer reuse of the Enterprise IT Keycloak patterns and existing PKI/RADIUS concepts,
but keep this lab self-contained unless the proven `br-eitcorp` seam materially
improves learning without making startup fragile.

Recommended stack after probe:

- Keycloak or another already-pinned OIDC IdP;
- `oauth2-proxy`, Pomerium, or equivalent identity-aware proxy/PEP;
- nginx applications with one public and two protected resources;
- mTLS client certificate as the lab device-trust signal;
- OPA/Rego only if it adds inspectable authorization value without turning the lab
  into a policy-language tutorial.

Live:

- OIDC login, tokens/claims, group-based authorization;
- per-resource policy and explicit deny;
- device-certificate requirement;
- short-lived session and revocation/termination behavior supported by the stack;
- network segmentation that prevents direct origin reachability;
- decision and access logs correlated by request/user/device.

Conceptual mapping: ZTNA/SSE/SASE PoP, posture/EDR signals, continuous risk, CASB,
SWG, DLP, and global service availability.

## Feature-probe gate

1. Pin compatible IdP and proxy versions.
2. Prove non-interactive creation of realm/clients/groups/users without checked-in
   admin secrets beyond explicit lab credentials.
3. Prove OIDC login and group claim authorization.
4. Prove mTLS-required access and rejection without a trusted client cert.
5. Prove direct origin traffic is blocked independently of proxy policy.
6. Determine actual token/session revocation semantics and document them accurately.
7. Prove clean redeploy resets identity state deterministically.

If browser interaction cannot be tested deterministically, use an approved CLI OIDC
device/auth-code helper for automated checks while retaining a documented optional
browser walkthrough.

## Lab type and platform

- Type: practice.
- Linux containers: `idp`, `pep`, `public-app`, `finance-app`, `ops-app`, `pki`,
  `managed-client`, `unmanaged-client`, `admin-client`, `log-viewer`.
- `seg-gw`: cEOS only if useful for VRF/ACL operations; otherwise a Linux nftables
  gateway better exposes origin-bypass policy and saves resources.
- Pin images; build a small `zt-access-tools:local` image for OIDC/mTLS test helpers.

## Topology/addressing

```text
 managed-client --- internet/remote --- pep --- finance-app
 unmanaged-client --------|              \---- ops-app
 admin-client -------------|        idp / pki / decision logs
                                     |
                              segmented origin network
```

| Zone | Prefix | Purpose |
|---|---|---|
| Remote/untrusted | `10.90.10.0/24` | User source |
| PEP/edge | `10.90.20.0/24` | Published access point |
| Identity services | `10.90.30.0/24` | IdP/PKI/logs |
| Protected origins | `10.90.40.0/24` | Finance/operations apps |
| Management | `10.90.50.0/24` | Admin-only plane |

Prebuild networking, IdP foundation, users/groups, PKI root, application endpoints,
and log collection. Withhold PEP clients/policies, resource mappings, client certs,
and origin segmentation rules.

## Student task sequence

1. **Guided trust-boundary survey:** attempt direct and proxied paths from each
   client; inspect empty PEP policy and identity/resource inventory.
2. **Hinted identity integration:** register PEP with IdP, configure secure redirect,
   issuer/audience validation, and map the required group claim.
3. **Hinted resource policy:** finance users reach finance; operations users reach
   operations; neither gains access solely because it is on an internal subnet.
4. **Hinted device signal:** issue a client cert to `managed-client`, require it for
   finance, reject valid users from `unmanaged-client`, and log the decision reason.
5. **Hinted origin protection:** allow origins only from PEP and admin health-check
   paths. Prove spoofing DNS or connecting by IP cannot bypass policy.
6. **Hinted session lifecycle:** observe token expiry, user disable or session revoke,
   and the actual delay until access is denied; explain cached-policy implications.
7. **Open partner access case:** design least-privilege access for a partner group to
   one route without exposing management or another app.
8. **Break-It:** a new broad network rule permits remote clients to reach
   `finance-app` directly. PEP tests remain correct, so dashboard-only validation
   misses the breach. Diagnose from path/capture/firewall counters, close origin
   access, and verify both intended permit and all bypass denies.

## Make the invisible visible

- Decode claims without exposing signing secrets; trace issuer/audience/group.
- Correlate one request across PEP decision and origin access logs.
- Show TLS client-certificate identity and validation result.
- Capture direct-origin denial versus proxy-origin permit.
- Compare network location with resource/user/device decision inputs.

## Automated checks

`check.sh` must assert at minimum:

1. IdP and PEP ready with TLS.
2. Tokens from wrong issuer/audience are rejected.
3. Finance managed user/device reaches finance.
4. Same user on unmanaged client is denied finance.
5. Operations group reaches ops but not finance.
6. Partner reaches only its approved route.
7. Anonymous client reaches public app only.
8. No remote client reaches protected origin directly by name or IP.
9. PEP can reach origins only on required ports.
10. Protected origins cannot initiate into remote or identity management zones.
11. Revoked/disabled access changes within the accurately documented bound.
12. Every permit/deny has a correlated decision log.
13. Break-It bypass fails even when proxied tests still pass.

## Security constraints

- Use conspicuous lab-only credentials and keys; never copy production-looking secrets.
- Keep private keys scoped to the lab and excluded from docs output.
- Do not disable TLS verification in a solution.
- Do not call a static client certificate full device posture; name the limitation.
- Coordinate with, but do not overwrite, untracked OPNsense worktree artifacts.

## Planned files/docs

- Standard lab files plus bootstrap scripts, policy files, PKI, `PROBE.md`, and
  `VALIDATION.md`.
- `docs/tracks/security/zero-trust-secure-access.md`; cross-register in Enterprise
  and Security study paths without duplicating lab counts.
- Coverage map must list ZTNA live and SASE/SSE/CASB/DLP conceptual separately.

## Resource target

- Primarily Linux; target ≤ 5 GiB steady and ≤ 7 GiB peak.
- Readiness ≤ 180 seconds; use health endpoints, not fixed sleeps.

## Definition of done

All master gates apply. Validate every user/group/device matrix cell, token rejection,
origin bypass denial, session behavior, and logs. The Break-It must be caught by an
independent path assertion, proving policy tests alone are insufficient.
