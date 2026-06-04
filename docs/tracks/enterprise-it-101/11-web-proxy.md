---
title: "11 — Web Proxy & Filtering"
---

!!! tip "Advanced Services Lab 2 of 3"
    Deploy Squid with Kerberos Negotiate authentication, configure AD group-based ACLs, and enable access logging — transparent enterprise web filtering without password prompts.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/11-web-proxy/`  
**Requires:** Foundation + Labs 05–10

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `proxy1` | `squid-ad:local` (custom) | `10.100.2.40` | Squid proxy with AD auth |
| `webserver1` | `nginx:alpine` | `10.100.2.41` | "Allowed" internal web server |
| `webserver2` | `nginx:alpine` | `10.100.2.42` | "Blocked" web server |

## What is Pre-Built

- Squid installed and running with basic config (no auth)
- Two web servers serving distinct pages
- Workstation `HTTP_PROXY` not yet configured

## What You Configure

**1. Generate a Kerberos keytab for Squid**

```bash
docker exec proxy1 msktutil -c \
  -s HTTP/proxy1.lab.corp \
  -k /etc/squid/squid.keytab \
  --server dc1.lab.corp
```

**2. Configure Kerberos Negotiate auth in squid.conf**

```
auth_param negotiate program \
  /usr/lib/squid/negotiate_kerberos_auth \
  -s HTTP/proxy1.lab.corp \
  -k /etc/squid/squid.keytab
auth_param negotiate children 10
acl authenticated proxy_auth REQUIRED
```

**3. Create AD group-based ACLs**

```
# Allow engineering full access
acl engineering_grp proxy_auth_regex alice|carol   # or use external_acl with LDAP

# Block finance from webserver2
acl blocked_site dstdomain webserver2.lab.corp
http_access deny finance_grp blocked_site
http_access allow authenticated
http_access deny all
```

**4. Configure workstations to use the proxy**

```bash
# On ws1:
export http_proxy=http://proxy1.lab.corp:3128
export https_proxy=http://proxy1.lab.corp:3128
```

**5. Test access control**

```bash
# Alice (engineering) — both sites allowed
su - alice -c "curl -x http://proxy1.lab.corp:3128 http://webserver2.lab.corp"

# Bob (finance) — webserver2 blocked
su - bob -c "curl -x http://proxy1.lab.corp:3128 http://webserver2.lab.corp"
# → HTTP 403 Forbidden
```

## Verification Commands

```bash
# Test proxy without auth (should fail — auth required)
curl -x http://proxy1.lab.corp:3128 http://webserver1.lab.corp

# Test with Kerberos negotiate auth
curl -x http://proxy1.lab.corp:3128 --negotiate -u : http://webserver1.lab.corp

# Verify blocking
curl -x http://proxy1.lab.corp:3128 --negotiate -u : http://webserver2.lab.corp
# → 403

# Live access log — see user, URL, action
docker exec proxy1 tail -f /var/log/squid/access.log
# Format: timestamp  user@LAB.CORP  URL  TCP_DENIED|200
```

## What This Lab Teaches

- Enterprise web proxies serve three purposes: **access control, logging, and caching**
- **Kerberos Negotiate auth** provides transparent authentication — no password prompts in browsers
- **AD group-based ACLs** enforce different policies for different departments from a single proxy
- Access logs answer "who went where and when" — essential for compliance and forensics
- SSL/TLS bump (conceptual) is how proxies inspect HTTPS traffic — and why it's controversial

## Experiments

- Remove the proxy setting on `ws1` and access the "blocked" site directly — it works (proxy only filters traffic that flows through it)
- Configure Squid to cache responses, load a page twice, and verify `TCP_HIT` appears in the log
- Add a PAC (Proxy Auto-Config) file and serve it via DHCP option 252
- Discuss (do not implement) SSL bump: why it requires a CA cert, what it intercepts, and the trust implications
