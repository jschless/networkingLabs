---
title: "04 — Domain Join & Identity"
---

!!! tip "Foundation Lab 4 of 4"
    Join Linux workstations to the `lab.corp` domain using realmd and sssd, and understand what "domain membership" actually creates in Active Directory.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/04-domain-join/`  
**Requires:** Labs 01–03 running

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `ws1` | `workstation:local` | `10.100.10.11` | Employee workstation |
| `ws2` | `workstation:local` | `10.100.10.12` | Second workstation |

**Modified:** `admin-ws` (joins domain)

## What is Pre-Built

- Workstation images have sssd, realmd, and krb5-user installed
- `/etc/resolv.conf` pointed at `dc1`
- `/etc/krb5.conf` template with `LAB.CORP` realm

## What You Configure

**1. Discover and join the domain from ws1**

```bash
docker exec -it ws1 bash

# Discover
realm discover lab.corp

# Join (prompts for Administrator password)
realm join -U Administrator lab.corp
```

**2. Verify the join**

```bash
realm list
# sssd.conf was auto-generated at /etc/sssd/sssd.conf
cat /etc/sssd/sssd.conf
```

**3. Test AD login**

```bash
id alice@lab.corp
su - alice@lab.corp
```

**4. Enable short-name login**

Edit `/etc/sssd/sssd.conf`:
```ini
use_fully_qualified_names = False
```

```bash
systemctl restart sssd
su - alice    # works without @lab.corp
```

**5. Verify home directory and groups**

```bash
ls /home/alice@lab.corp/
getent group engineering@lab.corp
```

**6. Group-based sudo**

```bash
# Add to /etc/sudoers.d/domain-admins:
%engineering@lab.corp ALL=(ALL) ALL
```

**7. Join ws2 and confirm both appear in AD**

```bash
docker exec dc1 samba-tool computer list
```

## Verification Commands

```bash
# Domain discovery
realm discover lab.corp

# After join
realm list
id alice@lab.corp
getent passwd alice@lab.corp
getent group engineering@lab.corp

# Kerberos ticket from domain user
su - alice@lab.corp -c "klist"

# Computer accounts in AD
docker exec dc1 samba-tool computer list
```

## GUI Checkpoint — LDAP Account Manager

After joining both workstations, open LAM and navigate to the Computers container. You should see `ws1$` and `ws2$` machine accounts alongside `admin-ws$`. Click into a computer object to see `operatingSystem`, `dNSHostName`, and `servicePrincipalName` — the same view a Windows admin sees in ADUC's Computers container.

## What This Lab Teaches

- **Domain join** is what makes a machine trust AD for authentication
- `realmd` automates what used to be 15 manual config file edits
- **sssd** caches credentials locally — users can log in even if AD is temporarily unreachable
- Computer accounts in AD track joined machines — domain membership is bidirectional
- PAM + NSS + sssd is the Linux equivalent of Windows domain authentication

## Experiments

- Stop `dc1`, try logging in with cached credentials — it works
- Clear the sssd cache (`sss_cache -E`), stop `dc1`, try again — it fails
- Create a second domain admin and delegate OU-level join permissions
- Run `journalctl -u sssd` to trace the LDAP/Kerberos conversation during login
- In LAM, move a computer object between OUs and see how GPO targeting would change (Lab 08 preview)
