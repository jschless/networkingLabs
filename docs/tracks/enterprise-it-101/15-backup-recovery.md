---
title: "15 — Backup & Disaster Recovery"
---

!!! tip "Operations Lab 3 of 4"
    Set up encrypted BorgBackup repositories for every critical service, run actual disaster scenarios, and restore from backup — backups are not real until you've tested a restore.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/15-backup-recovery/`  
**Requires:** Foundation + Labs 05–14

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `backup1` | `ubuntu:22.04` + BorgBackup | `10.100.3.40` | Backup server |

## What is Pre-Built

- BorgBackup installed on `backup1` and all service nodes
- SSH keys from `backup1` to all service nodes
- Backup directories created on `backup1`

## What You Configure

**1. Initialize encrypted Borg repositories**

```bash
docker exec -it backup1 bash

borg init --encryption=repokey \
  ssh://backup1/srv/backups/dc1

borg init --encryption=repokey \
  ssh://backup1/srv/backups/ca1

borg init --encryption=repokey \
  ssh://backup1/srv/backups/mail1

borg init --encryption=repokey \
  ssh://backup1/srv/backups/keycloak
```

**2. Run the first backups**

```bash
# AD (dc1) — back up Samba private/ and sysvol/
docker exec dc1 samba-tool dbcheck      # verify DB before backup
borg create \
  ssh://backup1/srv/backups/dc1::$(date +%Y%m%d-%H%M) \
  /var/lib/samba/private \
  /var/lib/samba/sysvol

# CA (ca1) — includes the root private key!
borg create \
  ssh://backup1/srv/backups/ca1::$(date +%Y%m%d-%H%M) \
  $(step path)

# Mail (mail1)
borg create \
  ssh://backup1/srv/backups/mail1::$(date +%Y%m%d-%H%M) \
  /var/mail /etc/postfix

# Keycloak DB
docker exec postgres-kc pg_dump keycloak > /tmp/keycloak.sql
borg create \
  ssh://backup1/srv/backups/keycloak::$(date +%Y%m%d-%H%M) \
  /tmp/keycloak.sql
```

**3. Verify the backups**

```bash
borg list ssh://backup1/srv/backups/dc1
borg info ssh://backup1/srv/backups/dc1::latest
borg extract --dry-run ssh://backup1/srv/backups/dc1::latest
```

**4. Disaster scenario — AD recovery**

```bash
# Simulate AD database corruption
docker exec dc1 bash -c "rm -rf /var/lib/samba/private/sam.ldb*"

# Verify AD is broken
docker exec dc1 samba-tool user list   # fails

# Restore from backup
borg extract ssh://backup1/srv/backups/dc1::latest

# Restart Samba and verify
docker exec dc1 systemctl restart samba
docker exec dc1 samba-tool user list        # succeeds
docker exec admin-ws kinit alice@LAB.CORP   # succeeds
```

**5. Disaster scenario — CA recovery**

```bash
# Delete the CA private key
docker exec ca1 rm -f $(step path)/secrets/root_ca_key

# Attempt to issue a cert — fails
docker exec admin-ws step ca certificate test.lab.corp t.crt t.key   # fails

# Restore the CA from backup
borg extract ssh://backup1/srv/backups/ca1::latest

# Issue a cert — succeeds
docker exec admin-ws step ca certificate test.lab.corp t.crt t.key   # succeeds
```

**6. Configure scheduled backups with retention**

```bash
# /usr/local/bin/backup-all.sh (cron: 0 2 * * *)
borg create --stats ssh://backup1/srv/backups/dc1::$(date +%Y%m%d) /var/lib/samba
borg prune \
  --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
  ssh://backup1/srv/backups/dc1
```

## Verification Commands

```bash
# List all archives
borg list ssh://backup1/srv/backups/dc1

# Archive details (size, deduplication ratio)
borg info ssh://backup1/srv/backups/dc1::latest

# Dry-run restore
borg extract --dry-run ssh://backup1/srv/backups/dc1::latest

# Post-restore AD checks
docker exec dc1 samba-tool user list
docker exec dc1 samba-tool dbcheck
docker exec admin-ws kinit alice@LAB.CORP
```

## What This Lab Teaches

- **Backups are not real until you've tested a restore** — this lab forces you to restore
- **AD is the most critical service**: if AD is gone, nothing else works (auth, DNS, GPO)
- **CA backup includes private keys** — these must be encrypted and access-controlled
- **Database backups** (`pg_dump`) are application-consistent; file copies of a live DB may not be
- **Retention policies** balance storage cost against recovery point objectives (RPO)
- The **3-2-1 rule**: 3 copies, 2 media types, 1 offsite — the gold standard

## Experiments

- Point-in-time recovery: create a user, take a backup, delete the user, restore, verify the user exists
- Attempt to restore a Borg archive without the passphrase — observe the failure
- Compare backup sizes with and without deduplication across multiple runs
- Simulate a "lost encryption key" scenario and discuss key escrow procedures
