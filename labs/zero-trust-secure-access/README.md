# Zero-Trust Secure Access — Practice Lab

Build a resource-centric access path: Keycloak issues OIDC claims, the PEP evaluates user group and an mTLS device credential, and the gateway keeps protected origins unreachable except from the PEP. This is a live ZTNA mechanism lab, not a reproduction of a commercial SASE platform.

## Topology

```text
managed / unmanaged clients -- remote 10.90.10.0/24 -- seg-gw -- PEP 10.90.20.10
                                                        |       \-- protected apps 10.90.40.0/24
                                                  IdP/PKI/logs 10.90.30.0/24
                                                        |
                                                  admin 10.90.50.0/24
```

| Zone | Prefix | Nodes |
|---|---|---|
| Remote/untrusted | `10.90.10.0/24` | `managed-client`, `unmanaged-client` |
| PEP edge | `10.90.20.0/24` | `pep` |
| Identity | `10.90.30.0/24` | `idp`, `pki`, `log-viewer` |
| Protected origins | `10.90.40.0/24` | `public-app`, `finance-app`, `ops-app` |
| Management | `10.90.50.0/24` | `admin-client` |

| User | Group | Credential | Intended access |
|---|---|---|---|
| `finuser` | `finance` | managed client certificate | `/finance` |
| `opsuser` | `operations` | none | `/ops` |
| `partneruser` | `partner` | none | `/partner` only |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure.** Commit to an answer before touching the CLI.
- **Open the hints before the solution.** The solution toggle is the answer key.
- **Verify like an operator.** Prove state with commands and evidence after each task.

## Deploy

```bash
cd labs/zero-trust-secure-access
mkdir -p runtime
docker build -t zt-access-tools:local .
docker build -f Dockerfile.keycloak -t zt-keycloak:local .
containerlab deploy -t topology.clab.yml
```

Wait for Keycloak discovery instead of sleeping:

```bash
docker exec clab-zero-trust-secure-access-managed-client \
  curl -fsS http://10.90.30.10:8080/realms/ztna/.well-known/openid-configuration
```

The setup intentionally has no protected-resource policy, client certificate, or origin boundary. Lab-only credentials are conspicuous and exist only for this disposable realm.

## Task 1 — Survey the trust boundary

**Objective:** Identify the five zones, prove a direct finance-origin request currently works, and show the PEP denies finance because no policy exists.

**Predict first:** Which result is a network failure and which is a PEP authorization decision?

<details markdown="1">
<summary>Hints</summary>

- Compare `curl http://10.90.40.11:8080/` with `curl -k https://10.90.20.10:8443/finance` from `unmanaged-client`.
- `nft list ruleset` on `seg-gw` reveals the initial forwarding stance.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
docker exec clab-zero-trust-secure-access-unmanaged-client curl -s http://10.90.40.11:8080/
docker exec clab-zero-trust-secure-access-unmanaged-client curl -sk -i https://10.90.20.10:8443/finance
docker exec clab-zero-trust-secure-access-seg-gw nft list ruleset
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The origin answers directly but the PEP returns `403` with `no-policy`. That contrast proves subnet location is not yet enforcing a resource decision.

</details>

## Task 2 — Integrate identity and resource claims

**Objective:** Obtain a short-lived OIDC access token for each user and determine the issuer, audience, and group claim that the PEP must validate.

**Predict first:** Can a token for `opsuser` authorize finance merely because both clients are in the remote subnet?

<details markdown="1">
<summary>Hints</summary>

- The token endpoint is in Keycloak discovery. Use password grant only as this lab's deterministic CLI helper.
- Decode the JWT payload locally; never print or copy Keycloak signing keys.
- The required audience is `pep`; the claim is named `groups`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
docker exec clab-zero-trust-secure-access-managed-client sh -c '
curl -fsS -X POST http://10.90.30.10:8080/realms/ztna/protocol/openid-connect/token \
  -d grant_type=password -d client_id=pep -d client_secret=LAB-ONLY-PEP-SECRET \
  -d username=finuser -d password=LAB-ONLY-finance-password > /tmp/fin.json
python3 -c "import base64,json; t=json.load(open('/tmp/fin.json'))['access_token'].split('.')[1]; print(json.loads(base64.urlsafe_b64decode(t+'='*(-len(t)%4))))"
'
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The decoded payload has issuer `http://10.90.30.10:8080/realms/ztna`, audience `pep`, and `groups: [finance]`. An operations token has a different group and must not become finance authorization.

</details>

## Task 3 — Define least-privilege resource policy

**Objective:** Install policy for finance (finance group and device certificate), operations (operations group), and partner (partner group on `/partner` only).

<details markdown="1">
<summary>Hints</summary>

- The PEP reads `/runtime/policy.json`; resource names are `finance`, `ops`, and `partner`.
- Each rule needs `groups` and `origin`; only finance needs `mtls: true`.
- Finance and partner both use the finance origin, but a route is still an authorization boundary.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
docker exec clab-zero-trust-secure-access-pep sh -c 'printf "%s" "{\"resources\":{\"finance\":{\"groups\":[\"finance\"],\"mtls\":true,\"origin\":\"10.90.40.11\"},\"ops\":{\"groups\":[\"operations\"],\"origin\":\"10.90.40.12\"},\"partner\":{\"groups\":[\"partner\"],\"origin\":\"10.90.40.11\"}}}" > /runtime/policy.json'
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`/public` remains anonymous. `/ops` accepts `opsuser` but rejects it at `/finance`; `partneruser` is accepted only at `/partner`.

</details>

## Task 4 — Enroll the managed device and require mTLS

**Objective:** Issue the managed client certificate and prove `finuser` can reach finance only when both identity and certificate are presented.

**Predict first:** What decision reason will appear if `finuser` presents a valid token from `unmanaged-client` without a certificate?

<details markdown="1">
<summary>Hints</summary>

- `pki` exposes an enrollment endpoint; certs appear under `/runtime/clients/` and the trust anchor is `/runtime/ca.crt`.
- Use `--cacert`, `--cert`, and `--key`; do not use `-k` for the completed path.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
docker exec clab-zero-trust-secure-access-pki curl -fsS -X POST http://127.0.0.1:8080/issue/managed-client
docker exec clab-zero-trust-secure-access-managed-client sh -c '
FIN_TOKEN=$(python3 -c "import json; print(json.load(open('/tmp/fin.json'))['access_token'])")
curl -fsS --cacert /runtime/ca.crt --cert /runtime/clients/managed-client.crt --key /runtime/clients/managed-client.key -H "Authorization: Bearer $FIN_TOKEN" https://10.90.20.10:8443/finance
'
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The managed request returns `finance-app`; the same token without client credentials receives `403` and a `device-certificate` decision log reason. This static certificate is a device-trust signal, not full posture/EDR evidence.

</details>

## Task 5 — Close the origin bypass

**Objective:** Permit only established replies, remote-to-PEP TLS, required Keycloak traffic, PEP-to-origin HTTP, and admin health paths; deny all other forwarding.

<details markdown="1">
<summary>Hints</summary>

- Use an `inet` table and a forward chain with policy drop on `seg-gw`.
- Interfaces are remote `eth1`, PEP `eth2`, identity `eth3`, origins `eth4`, management `eth5`.
- Preserve OIDC token and PEP introspection flows to `10.90.30.10:8080`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
docker exec clab-zero-trust-secure-access-seg-gw sh -c '
nft flush ruleset; nft add table inet zt
nft "add chain inet zt forward { type filter hook forward priority filter; policy drop; }"
nft add rule inet zt forward ct state established,related accept
nft add rule inet zt forward iif eth1 oif eth2 tcp dport 8443 accept
nft add rule inet zt forward iif eth1 oif eth3 ip daddr 10.90.30.10 tcp dport 8080 accept
nft add rule inet zt forward iif eth2 oif eth3 ip daddr 10.90.30.10 tcp dport 8080 accept
nft add rule inet zt forward iif eth2 oif eth4 ip saddr 10.90.20.10 tcp dport 8080 accept
nft add rule inet zt forward iif eth5 oif eth3 tcp dport 8080 accept
nft add rule inet zt forward iif eth5 oif eth4 ip daddr 10.90.40.10 tcp dport 8080 accept
'
```

</details>

<details markdown="1">
<summary>Check your work</summary>

Direct name/IP requests to all protected origins time out, while the PEP continues to proxy authorized traffic. `nft list ruleset` exposes the separate network enforcement point.

</details>

## Task 6 — Observe decisions and session lifecycle

**Objective:** Correlate a request across origin and PEP logs, then observe the actual 20-second Keycloak access-token lifetime.

**Predict first:** Does a valid, cached token remain usable indefinitely after its 20-second access-token expiry?

<details markdown="1">
<summary>Hints</summary>

- Send `X-Request-ID: lab-42`, then inspect `http://10.90.30.12:8080/` from `admin-client`.
- Keycloak introspection is evaluated per request; wait for expiry and retry, rather than claiming instant revocation.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
docker exec clab-zero-trust-secure-access-admin-client curl -fsS http://10.90.30.12:8080/ | tail
# Reuse a token after 21 seconds; the PEP responds 401 with inactive-token.
```

</details>

<details markdown="1">
<summary>Check your work</summary>

One shared request ID appears in the origin response and a PEP `permit` log. After expiry the PEP rejects the token; this lab documents a 20-second bound, not continuous risk scoring or an instantaneous revocation promise.

</details>

## Task 7 — Design partner access

**Objective:** Defend why `/partner` is a distinct resource rule even though it uses the finance origin, and show that the partner token fails at `/ops` and `/finance`.

<details markdown="1">
<summary>Hints</summary>

- Test every route, not just the expected allow.

</details>

<details markdown="1">
<summary>Solution</summary>

Use the `partner` rule from Task 3 and run `./scripts/lab.sh check zero-trust-secure-access`.

</details>

<details markdown="1">
<summary>Check your work</summary>

The automated matrix asserts partner permit only at `/partner`; route-level authorization is independent of the origin subnet.

</details>

## Task 8 — Break-It: detect a bypass outside the dashboard

**Objective:** Introduce a broad remote-to-origin forward rule, prove PEP tests still pass, then remove the rule and show the independent direct-path assertion catches the breach.

<details markdown="1">
<summary>Hints</summary>

- Insert, rather than append, an `eth1` to `eth4` TCP/8080 accept rule.
- Compare a valid managed PEP request with an unauthenticated direct finance-origin request.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./check.sh --break-it    # intentionally exits non-zero after proving the bypass
docker exec clab-zero-trust-secure-access-seg-gw nft delete rule inet zt forward handle "$(docker exec clab-zero-trust-secure-access-seg-gw nft -a list chain inet zt forward | awk '/iifname \"eth1\" oifname \"eth4\"/{print $NF}')"
./scripts/lab.sh check zero-trust-secure-access
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The Break-It check fails even while the valid PEP request works: dashboard-only policy validation misses the independent network bypass. Removing the one broad rule restores the complete pass.

</details>

## Verification

```bash
./scripts/lab.sh check zero-trust-secure-access
```

Expect permits for managed finance, operations, partner route, and anonymous public access; all other group/device/origin-path cells deny. For cleanup, run `containerlab destroy -t topology.clab.yml --cleanup` then `rm -rf runtime`.

## Challenge questions

1. Which additional signals would be needed before treating the mTLS certificate as device posture?
2. How would you prevent token replay if the PEP had multiple global points of presence?
3. Which logs and retention controls would support an audit investigation without storing token contents?
4. Where would CASB, SWG, and DLP fit around this resource proxy, and which remain conceptual here?

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Token request says account is not fully set up | Realm/import did not finish | wait for discovery; redeploy from an empty `runtime/` if the import was interrupted |
| TLS name or trust failure | Missing lab CA/certificate or using an IP without the generated CA | use `--cacert /runtime/ca.crt`; enroll `managed-client` |
| `inactive-token` | 20-second access token expired | obtain a new token; this is the documented session bound |
| PEP permits but direct origin works | Broad gateway rule bypasses the PEP | inspect `nft -a list chain inet zt forward`, remove the remote-to-origin rule |
