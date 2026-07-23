# Feature Probe Record — `zero-trust-secure-access`

## Scope and decision

- **Feature and learning objective:** prove a real OIDC issuer can create a realm non-interactively for an inspectable identity-aware PEP lab.
- **Decision:** go.
- **Reason and fidelity statement:** Keycloak 26.0.7 started, published discovery metadata, and accepted `kcadm.sh` realm creation. The completed lab uses Keycloak for OIDC and a deliberately small local PEP so its authorization and mTLS decisions can be inspected; it is not a commercial SASE service.
- **Owner and date:** Codex, 2026-07-23.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Ubuntu Linux, `5.15.0-181-generic`, x86_64 |
| ContainerLab version | `0.74.1` (commit `1866b3a2b`) |
| Docker version | Client/Server `29.5.3`, overlay2 |
| IdP image | `quay.io/keycloak/keycloak:26.0.7@sha256:4388e2379b7e870a447adbe7b80bd61f5fbf04e925832b19669fda4957f05a81` |
| Tools base image | `python:3.12.7-alpine3.20@sha256:5049c050bdc68575a10bcb1885baa0689b6c15152d8a56a7e399fb49f783bf98` |
| Host memory/disk before probe | 15 GiB RAM; 144 GiB free on `/` |

## Smallest load-bearing test

Disposable command (with an automatic `docker rm -f ztna-keycloak-probe` cleanup trap):

```text
docker run --rm -d --name ztna-keycloak-probe -p 127.0.0.1:18080:8080 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=lab-admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=LAB-ONLY-admin-credential \
  quay.io/keycloak/keycloak:26.0.7 start-dev
curl -fsS http://127.0.0.1:18080/realms/master/.well-known/openid-configuration
docker exec ztna-keycloak-probe /opt/keycloak/bin/kcadm.sh config credentials ...
docker exec ztna-keycloak-probe /opt/keycloak/bin/kcadm.sh create realms -s realm=probe -s enabled=true
```

After 22.7 seconds, discovery returned issuer `http://127.0.0.1:18080/realms/master`; `kcadm` reported `Created new realm with id 'probe'`; `get realms/probe` returned `"realm" : "probe"` and `"enabled" : true`. `docker stats --no-stream` measured `580.7MiB` for the probe.

## Cleanup and repeatability

- **Destroy/cleanup command:** automatic `docker rm -f ztna-keycloak-probe` trap.
- **Orphans checked:** `docker ps`; no probe container remained.
- **Second run:** the imported-realm workflow was later redeployed from an empty runtime directory; Keycloak again served discovery on the lab address.

## Unsupported behavior and fallback

The probe did not claim browser automation, commercial posture/EDR signals, CASB, SWG, DLP, global PoPs, or continuous risk scoring. CLI password grant is the approved deterministic OIDC helper; the README keeps browser login as an optional observation.
