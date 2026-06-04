---
title: "01 — Active Directory & DNS"
---

!!! tip "Foundation Lab 1 of 4"
    Build the core of `lab.corp`: a Samba Active Directory domain controller with integrated DNS, organizational units, users, groups, and Kerberos authentication.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/01-active-directory/`

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `dc1` | `samba-ad:local` (custom) | `10.100.1.10` | Samba AD Domain Controller |
| `admin-ws` | `workstation:local` (custom) | `10.100.10.10` | Admin workstation |
| `lam` | `ghcr.io/ldapaccountmanager/lam:stable` | `10.100.1.11` | LDAP Account Manager web GUI |

## What is Pre-Built

- Docker network `lab-corp` (10.100.0.0/16)
- Samba container with a provision script ready to run
- DNS resolution pointed at `dc1`

## What You Configure

**1. Provision the domain**

```bash
docker exec -it dc1 bash
samba-tool domain provision \
  --realm=LAB.CORP \
  --domain=LAB \
  --server-role=dc \
  --dns-backend=SAMBA_INTERNAL \
  --adminpass='P@ssw0rd1'
```

**2. Start Samba and verify it is listening**

```bash
samba &
ss -tlnp | grep -E '389|88|53|636'
```

**3. Create organizational units**

```bash
samba-tool ou create "OU=Employees,DC=lab,DC=corp"
samba-tool ou create "OU=Workstations,DC=lab,DC=corp"
```

**4. Create users**

```bash
samba-tool user create alice P@ssw0rd1 --given-name=Alice --surname=Smith
samba-tool user create bob   P@ssw0rd1 --given-name=Bob   --surname=Jones
```

**5. Create groups and add members**

```bash
samba-tool group add engineering
samba-tool group add finance
samba-tool group addmembers engineering alice
samba-tool group addmembers finance bob
```

**6. Verify from admin-ws**

```bash
docker exec -it admin-ws bash
# DNS
dig @10.100.1.10 dc1.lab.corp A
# LDAP
ldapsearch -H ldap://dc1.lab.corp -b "DC=lab,DC=corp" \
  -D "alice@lab.corp" -W "(objectClass=user)"
# Kerberos
kinit alice@LAB.CORP
klist
```

## Verification Commands

```bash
# SRV records — how clients find the domain controller
dig @10.100.1.10 lab.corp SOA
dig @10.100.1.10 _ldap._tcp.lab.corp SRV
dig @10.100.1.10 _kerberos._tcp.lab.corp SRV

# LDAP search with bind credentials
ldapsearch -H ldap://dc1.lab.corp \
  -b "DC=lab,DC=corp" \
  -D "alice@lab.corp" -W \
  "(objectClass=user)"

# Kerberos round-trip
kinit alice@LAB.CORP
klist
kvno ldap/dc1.lab.corp@LAB.CORP
```

## GUI Exploration — LDAP Account Manager

LAM at `https://lam.lab.corp:443` gives you the visual experience of Windows ADUC.

1. Configure LAM to connect to `ldap://dc1.lab.corp` with base DN `DC=lab,DC=corp`
2. Browse the OU tree — see how `OU=Employees` nests under the domain root
3. Click into alice's user object — inspect all LDAP attributes (memberOf, objectSID, userPrincipalName)
4. Create user "bob" via the GUI, then verify with `samba-tool user list`

## What This Lab Teaches

- **AD is three services in a trenchcoat**: LDAP (directory), Kerberos (auth), DNS (service location)
- **SRV records** are how clients find domain controllers — not static config
- **OUs** are organizational containers; **groups** are permission containers — different purposes
- `kinit` + `klist` is how you debug Kerberos, not logs

## Experiments

- Delete `_ldap._tcp.lab.corp` SRV record, then try `kinit` — watch it fail
- Create a Group Policy Object with `samba-tool gpo create` (preview of Lab 08)
- Add a second user and test cross-user LDAP search permissions
- In LAM, explore `CN=Configuration` and `CN=Schema` to see AD's internal structure
