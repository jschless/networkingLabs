---
title: "16 — Capstone: The Mini Enterprise"
---

!!! tip "Capstone Lab"
    All services from Labs 01–15 running simultaneously. Onboard a new employee end-to-end, fix three deliberately broken services, and draw the architecture diagram.

**Duration:** 3–4 hours  
**Directory:** `enterprise-it-101/labs/16-capstone/`  
**Requires:** All previous labs completed

## Start the Full Stack

```bash
docker compose \
  -f enterprise-it-101/labs/16-capstone/docker-compose.yml \
  up -d
```

This single compose file brings up the entire `lab.corp` infrastructure.

---

## Part A — New Employee Onboarding (45 min)

A new employee, "Dave", is joining the engineering team. Provision him end-to-end across every service.

**Tasks:**

1. Create Dave's AD account in the correct OU with the correct group membership
2. Verify NTP sync on his workstation
3. Join his workstation to the `lab.corp` domain
4. Verify he can log in with AD credentials
5. Verify he can access the engineering file share but **not** the finance share
6. Verify he can send and receive email as `dave@lab.corp`
7. Verify he can log into the sample app via Keycloak SSO
8. Verify he gets VLAN 10 via RADIUS when authenticating to the network
9. Verify the web proxy allows his traffic and logs his browsing
10. Verify his workstation appears in monitoring and SIEM

**Completion checklist:**

```
[ ] AD account created in OU=Employees,DC=lab,DC=corp
[ ] Member of engineering group
[ ] Visible in LAM with correct attributes and group membership
[ ] Workstation domain-joined, appears in samba-tool computer list
[ ] kinit dave@LAB.CORP returns a TGT
[ ] File share: //fs1.lab.corp/engineering — accessible
[ ] File share: //fs1.lab.corp/finance    — denied
[ ] swaks --to dave@lab.corp succeeds; dave can read IMAP inbox
[ ] SSO login to sample-app works; JWT contains "engineering" group
[ ] radtest dave ... returns Tunnel-Private-Group-Id = 10
[ ] Proxy access log shows dave@LAB.CORP entries
[ ] Wazuh agent running on dave's workstation, events flowing to dashboard
[ ] Grafana shows node metrics for dave's workstation
```

---

## Part B — Break/Fix Troubleshooting (1–1.5 h)

Three services have been deliberately broken. Run the break scripts first:

```bash
bash enterprise-it-101/labs/16-capstone/configs/break-scripts/break-dns.sh
bash enterprise-it-101/labs/16-capstone/configs/break-scripts/break-kerberos.sh
bash enterprise-it-101/labs/16-capstone/configs/break-scripts/break-email.sh
```

Then diagnose and fix each problem. Work through them one at a time.

---

### Break 1 — DNS Failure

**Symptom:** Domain logins fail. `realm discover lab.corp` hangs.

**Hint:** The conditional forwarder on `dns1` is pointing at the wrong IP.

**Diagnostic approach:**
```bash
dig @10.100.1.40 dc1.lab.corp A         # times out or SERVFAIL?
dig @10.100.1.40 _ldap._tcp.lab.corp SRV
cat /etc/bind/named.conf.options        # check the forwarder IP
```

**Fix:** Correct the forwarder IP back to `10.100.1.10` (dc1) and reload BIND.

---

### Break 2 — Kerberos Clock Skew

**Symptom:** `kinit` returns "Clock skew too great" across all clients. All AD-integrated services fail.

**Hint:** The clock on `dc1` has been skewed by 10 minutes.

**Diagnostic approach:**
```bash
date                                  # check your own clock
docker exec dc1 date                  # compare with dc1
chronyc tracking                      # is chrony correcting?
kinit alice@LAB.CORP                  # confirm the error
```

**Fix:** Fix dc1's clock, force a chrony sync, verify Kerberos authentication recovers.

```bash
docker exec dc1 chronyc makestep
kinit alice@LAB.CORP                  # should succeed
```

---

### Break 3 — Email Authentication Failure

**Symptom:** Users cannot authenticate to IMAP. Mail delivery from external domains bounces.

**Hint:** The LDAP bind password in docker-mailserver's config has been changed.

**Diagnostic approach:**
```bash
docker exec mail1 tail -50 /var/log/mail/mail.log   # look for LDAP bind error
docker exec mail1 cat /etc/docker-mailserver/mailserver.env | grep LDAP
```

**Fix:** Correct `LDAP_BIND_PW` in `mailserver.env`, restart the mail container, verify IMAP login.

---

## Part C — Architecture Documentation (30 min)

Draw a diagram of the complete `lab.corp` infrastructure showing:

- All containers, their IPs, and their roles
- Authentication flows (which services authenticate against AD, and how — LDAP, Kerberos, RADIUS)
- DNS resolution chain (which resolvers talk to which authoritative servers)
- Certificate trust chain (which services hold certs from `ca1`, and what clients trust them)
- Monitoring and SIEM data flows (which agents report to which collectors)

This is a paper or whiteboard exercise. The goal is to verify that you understand how everything connects — not just how to configure each service in isolation.

---

## What This Lab Teaches

- Enterprise IT is a **system of interdependencies** — not isolated services
- **Onboarding exercises the entire stack**: provisioning one employee touches every system
- **Troubleshooting requires understanding the dependency chain**: DNS → Kerberos → everything else
- **Documentation is a deliverable**, not an afterthought — the diagram is as important as the config
- The skills from this curriculum — AD, PKI, DNS, email, SSO, RADIUS, monitoring, SIEM — are the foundation of every enterprise IT environment
