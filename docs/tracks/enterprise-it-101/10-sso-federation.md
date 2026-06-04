---
title: "10 — SSO & Federation"
---

!!! tip "Advanced Services Lab 1 of 3"
    Deploy Keycloak as an OIDC identity provider, federate it with Active Directory, protect a sample web app with single sign-on, and add TOTP MFA — the open-source ADFS stack.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/10-sso-federation/`  
**Requires:** Foundation + Labs 05–09

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `keycloak` | `quay.io/keycloak/keycloak:latest` | `10.100.2.30` | Identity provider (IdP) |
| `sample-app` | Custom Flask app | `10.100.2.31` | OIDC-protected web application |
| `postgres-kc` | `postgres:15` | `10.100.2.32` | Keycloak database |

## What is Pre-Built

- Keycloak running with an empty realm
- Sample Flask app with OIDC middleware but no IdP configured
- TLS cert from `ca1` installed on Keycloak

## What You Configure

**1. Create a realm in Keycloak**

Open `https://keycloak.lab.corp:8443`, log in as admin, create realm `lab-corp`.

**2. Configure LDAP User Federation**

In Keycloak → `lab-corp` realm → User Federation → Add LDAP provider:
```
Connection URL:  ldap://dc1.lab.corp
Users DN:        CN=Users,DC=lab,DC=corp
Bind DN:         CN=keycloak-svc,CN=Users,DC=lab,DC=corp
Bind credential: P@ssw0rd1
```

Click **Sync all users** — AD users appear in Keycloak.

**3. Create an OIDC client for the sample app**

```
Client ID:     sample-app
Redirect URI:  https://sample-app.lab.corp:5000/callback
Client secret: (auto-generated)
```

**4. Configure the sample app**

In `sample-app/config.py`:
```python
KEYCLOAK_URL    = "https://keycloak.lab.corp:8443"
REALM           = "lab-corp"
CLIENT_ID       = "sample-app"
CLIENT_SECRET   = "<secret from step 3>"
```

**5. Test the OIDC login flow**

Access `https://sample-app.lab.corp:5000` → redirected to Keycloak → login as alice → redirected back with a JWT token.

**6. Enable TOTP MFA**

In Keycloak → Authentication → Required Actions: enable **Configure OTP** as required.

Next login as alice: Keycloak prompts for TOTP setup.
```bash
# Generate TOTP code from the CLI
oathtool --totp -b <base32-secret-from-qr-code>
```

## Verification Commands

```bash
# Keycloak health
curl -k https://keycloak.lab.corp:8443/health

# OIDC discovery endpoint
curl -k https://keycloak.lab.corp:8443/realms/lab-corp/.well-known/openid-configuration | jq

# Get a token (Resource Owner Password Grant — testing only)
curl -k -X POST \
  https://keycloak.lab.corp:8443/realms/lab-corp/protocol/openid-connect/token \
  -d "client_id=sample-app" \
  -d "client_secret=<secret>" \
  -d "username=alice" \
  -d "password=P@ssw0rd1" \
  -d "grant_type=password" | jq

# Decode the JWT (no verification — just inspect claims)
echo "<access_token>" | cut -d. -f2 | base64 -d | jq

# TOTP code from CLI
oathtool --totp -b <secret-from-qr>
```

## What This Lab Teaches

- **SSO** means "authenticate once, access many apps" — Keycloak is the open-source ADFS equivalent
- **OIDC** is the modern standard (JSON/REST); **SAML** is the legacy standard (XML/POST)
- **User federation** means Keycloak does not store passwords — AD does. Keycloak is a broker.
- **JWTs** contain claims (identity, group membership) that apps consume directly without hitting AD
- **MFA** adds a second factor — Keycloak handles enrollment, not the app
- The Authorization Code flow: app → IdP → login → code → token → app

## Experiments

- Decode the JWT and find the group memberships — map AD groups to Keycloak roles
- Disable the LDAP federation and watch login break (Keycloak can't validate passwords against AD)
- Configure a second app and verify SSO works — login once, access both apps without re-authenticating
- Set up client-certificate authentication as an alternative to password + MFA
