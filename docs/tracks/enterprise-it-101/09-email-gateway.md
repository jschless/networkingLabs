---
title: "09 — Email Gateway"
---

!!! tip "Core Services Lab 5 of 5"
    Deploy a full mail server using docker-mailserver, integrate LDAP authentication with Active Directory, and understand SMTP, IMAP, TLS, DKIM, and spam filtering.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/09-email-gateway/`  
**Requires:** Foundation + Labs 05–08

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `mail1` | `ghcr.io/docker-mailserver/docker-mailserver:latest` | `10.100.2.20` | Postfix + Dovecot mail server |

## What is Pre-Built

- docker-mailserver running with a basic config
- MX record for `lab.corp` pointed at `mail1`
- TLS certificate from `ca1` (Lab 03) pre-installed

## What You Configure

**1. Configure LDAP authentication**

In `mailserver.env`:
```env
LDAP_SERVER_HOST=ldap://dc1.lab.corp
LDAP_SEARCH_BASE=DC=lab,DC=corp
LDAP_BIND_DN=CN=mail-svc,CN=Users,DC=lab,DC=corp
LDAP_BIND_PW=P@ssw0rd1
ACCOUNT_PROVISIONER=LDAP
```

**2. Add MX record in Samba DNS**

```bash
docker exec dc1 samba-tool dns add \
  dc1.lab.corp lab.corp @ MX "mail1.lab.corp 10" -U Administrator
```

**3. Send mail between AD users**

```bash
docker exec -it ws1 bash

# From alice to bob
swaks --to bob@lab.corp \
      --from alice@lab.corp \
      --server mail1.lab.corp \
      --tls
```

**4. Check bob's inbox via IMAP**

```bash
curl -k imaps://mail1.lab.corp/INBOX \
  -u bob@lab.corp:P@ssw0rd1
```

**5. Enable SpamAssassin**

In `mailserver.env`:
```env
ENABLE_SPAMASSASSIN=1
SPAMASSASSIN_SPAM_TO_JUNK=1
```

**6. Configure DKIM signing**

```bash
docker exec mail1 setup config dkim
# This generates a DKIM key pair
# Add the TXT record shown to your DNS
```

**7. Configure a mail alias**

```bash
docker exec mail1 setup alias add postmaster@lab.corp alice@lab.corp
```

## Verification Commands

```bash
# MX lookup
dig @10.100.1.10 lab.corp MX

# Send test email with TLS
swaks --to bob@lab.corp --from alice@lab.corp \
      --server mail1.lab.corp --tls

# Check delivery via IMAP
curl -k imaps://mail1.lab.corp/INBOX -u bob@lab.corp:P@ssw0rd1

# Check mail logs
docker exec mail1 tail -20 /var/log/mail/mail.log

# Test spam filter with GTUBE string
swaks --to bob@lab.corp --from spammer@external.com \
      --server mail1.lab.corp \
      --body "XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X"
```

## What This Lab Teaches

- Email is **SMTP** (sending) + **IMAP/POP3** (receiving) — two separate protocols
- **LDAP integration** means AD users automatically have mailboxes — no separate account creation
- **MX records** tell the world where to deliver mail for your domain
- TLS on SMTP (STARTTLS) and IMAPS are non-negotiable in a real enterprise
- **DKIM**, **SPF**, and **DMARC** are the anti-spoofing layers every mail admin must understand

## Experiments

- Send mail without TLS, capture with tcpdump, read the plaintext — see why TLS matters
- Misconfigure the LDAP bind DN and watch authentication fail at IMAP login
- Set up a mail relay scenario: simulate external mail → `mail1` → internal delivery
- Add SPF and DMARC DNS records and test with an external validator tool
