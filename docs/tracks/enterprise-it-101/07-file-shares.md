---
title: "07 — File Shares & ACLs"
---

!!! tip "Core Services Lab 3 of 5"
    Deploy a Samba domain member file server, configure per-department shares with AD group access control, and mount them with Kerberos from domain-joined workstations.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/07-file-shares/`  
**Requires:** Foundation + Labs 05–06

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `fs1` | `samba-ad:local` (member server mode) | `10.100.2.10` | Samba file server |

## What is Pre-Built

- Samba installed as a domain member (not a DC)
- Shared directories created: `/srv/shares/engineering`, `/srv/shares/finance`, `/srv/shares/public`
- `fs1` already joined to the domain

## What You Configure

**1. Create AD groups and users**

```bash
docker exec dc1 samba-tool group add finance
docker exec dc1 samba-tool user create charlie P@ssw0rd1
docker exec dc1 samba-tool group addmembers finance bob
docker exec dc1 samba-tool group add all-staff
docker exec dc1 samba-tool group addmembers all-staff alice,bob,charlie
```

**2. Configure Samba shares in smb.conf**

```ini
[engineering]
    path = /srv/shares/engineering
    valid users = @engineering
    read only = no

[finance]
    path = /srv/shares/finance
    valid users = @finance
    read only = no

[public]
    path = /srv/shares/public
    valid users = @"all-staff"
    read only = yes
```

**3. Set POSIX ACLs**

```bash
setfacl -m g:engineering:rwx /srv/shares/engineering
setfacl -m g:finance:rwx    /srv/shares/finance
setfacl -m g:all-staff:r-x  /srv/shares/public
```

**4. Test access from ws1**

```bash
docker exec -it ws1 bash

# As alice (engineering) — should succeed
su - alice -c "smbclient //fs1.lab.corp/engineering -k -c 'put /etc/hostname test.txt'"

# As bob (finance) — denied on engineering, allowed on finance
su - bob -c "smbclient //fs1.lab.corp/engineering -k"   # 403
su - bob -c "smbclient //fs1.lab.corp/finance -k -c ls"  # OK
```

**5. Mount via CIFS with Kerberos**

```bash
kinit alice@LAB.CORP
mount -t cifs //fs1.lab.corp/engineering /mnt \
  -o sec=krb5,cruid=$(id -u)
ls /mnt/
```

## Verification Commands

```bash
# List available shares
smbclient -L //fs1.lab.corp -k

# Access with Kerberos
smbclient //fs1.lab.corp/engineering -k -c "ls; put testfile.txt"

# CIFS Kerberos mount
mount -t cifs //fs1.lab.corp/engineering /mnt -o sec=krb5,cruid=$(id -u)

# Check effective permissions
smbcacls //fs1.lab.corp/engineering / -k

# Audit access log
docker exec fs1 grep smbd_audit /var/log/samba/log.smbd
```

## What This Lab Teaches

- File shares are the oldest and most universal enterprise service
- **Samba bridges two ACL systems**: POSIX ACLs (Linux filesystem) and Windows ACLs — both must match
- `sec=krb5` mount option means the file server never sees the user's password
- **Access auditing** answers "who deleted that file?"
- AD group membership controls share access — no per-user share config required

## Experiments

- Enable Samba audit logging (`vfs objects = full_audit`) and trace file operations
- Create a nested permission structure and test ACL inheritance
- Try NTLM auth (`-U alice%password`) vs Kerberos (`-k`) and compare the Wireshark traffic
- Set a directory quota and test enforcement
