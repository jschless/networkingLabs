---
title: "03 — Certificate Authority & PKI"
---

!!! tip "Foundation Lab 3 of 4"
    Stand up an internal CA with Smallstep, enable LDAPS on your domain controller, and learn why every enterprise service needs certificates from somewhere.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/03-certificate-authority/`  
**Requires:** Labs 01–02 running

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `ca1` | `smallstep/step-ca:latest` | `10.100.1.30` | Internal certificate authority |

## What is Pre-Built

- step-ca container running but not bootstrapped
- Helper script `ca-init.sh` ready to run
- `ca1` hostname registered in Samba DNS

## What You Configure

**1. Initialize the CA**

```bash
docker exec -it ca1 bash
step ca init \
  --name="Lab Corp CA" \
  --dns=ca1.lab.corp \
  --address=:443 \
  --provisioner="admin@lab.corp"
```

**2. Register the CA in Samba DNS**

```bash
docker exec dc1 samba-tool dns add \
  dc1.lab.corp lab.corp ca1 A 10.100.1.30 -U Administrator
```

**3. Bootstrap trust on admin-ws**

```bash
docker exec -it admin-ws bash
step ca bootstrap \
  --ca-url https://ca1.lab.corp \
  --fingerprint <root-fingerprint-from-step-ca-init>
```

**4. Issue a certificate for dc1**

```bash
step ca certificate dc1.lab.corp dc1.crt dc1.key \
  --ca-url https://ca1.lab.corp
```

**5. Enable LDAPS on dc1**

```bash
# Add to /etc/samba/smb.conf under [global]:
# tls enabled  = yes
# tls keyfile  = /etc/samba/tls/dc1.key
# tls certfile = /etc/samba/tls/dc1.crt
# tls cafile   = /root/.step/certs/root_ca.crt

# Copy certs and restart Samba
docker cp dc1.crt dc1:/etc/samba/tls/
docker cp dc1.key dc1:/etc/samba/tls/
docker exec dc1 pkill -HUP samba
```

**6. Verify LDAPS from admin-ws**

```bash
ldapsearch -H ldaps://dc1.lab.corp \
  -b "DC=lab,DC=corp" \
  -D "alice@lab.corp" -W \
  "(objectClass=user)"
```

**7. Issue a wildcard cert for later labs**

```bash
step ca certificate "*.lab.corp" wildcard.crt wildcard.key \
  --ca-url https://ca1.lab.corp
```

## Verification Commands

```bash
# CA health
step ca health --ca-url https://ca1.lab.corp

# Certificate details
openssl x509 -in dc1.crt -text -noout \
  | grep -E "Issuer|Subject|Not After"

# TLS handshake test
openssl s_client \
  -connect dc1.lab.corp:636 \
  -CAfile /root/.step/certs/root_ca.crt

# Full chain verification
step certificate verify dc1.crt \
  --roots /root/.step/certs/root_ca.crt
```

## What This Lab Teaches

- Every encrypted enterprise service needs a certificate from somewhere
- Public CAs will not issue certs for internal domains like `.corp` — you need an internal CA
- **LDAPS** is LDAP + TLS, but the trust chain must be complete or clients reject it
- Root CA → issue cert → install cert → distribute root → verify: this is the workflow
- `openssl s_client` and `step certificate verify` are the debugging tools

## Experiments

- Issue a cert with `--not-after=2m`, wait for it to expire, and watch LDAPS break
- Create an intermediate CA and issue certs from it instead of the root
- Revoke a certificate and test whether Samba still accepts connections (CRL/OCSP discussion)
