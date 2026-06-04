---
title: "02 — NTP & Time Services"
---

!!! tip "Foundation Lab 2 of 4"
    Learn why time synchronization is not optional in an Active Directory environment — and what happens when Kerberos detects a clock skew.

**Duration:** 1.5–2 hours  
**Directory:** `enterprise-it-101/labs/02-ntp-time-services/`  
**Requires:** Lab 01 foundation running

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `ntp1` | `ubuntu:22.04` + chrony | `10.100.1.20` | Stratum-2 NTP server |

**Modified:** `dc1` (chrony client), `admin-ws` (chrony client)

## What is Pre-Built

- chrony installed on all nodes
- `ntp1` configured as a server but pointing at an unreachable upstream

## What You Configure

**1. Fix ntp1's upstream source**

```bash
docker exec -it ntp1 bash
# Edit /etc/chrony/chrony.conf
# Replace the broken upstream with:
server pool.ntp.org iburst
```

**2. Point dc1 and admin-ws at ntp1**

```bash
# In /etc/chrony/chrony.conf on each client:
server 10.100.1.20 iburst
```

**3. Verify sync**

```bash
chronyc sources -v
chronyc tracking
timedatectl status
```

**4. Demonstrate Kerberos clock-skew tolerance**

```bash
# On admin-ws: skew the clock by 10 minutes
date -s "+10 min"

# Attempt Kerberos authentication — this will fail
kinit alice@LAB.CORP
# kinit: Clock skew too great while getting initial credentials

# Fix the clock, then retry
chronyc makestep
kinit alice@LAB.CORP   # succeeds
```

## Verification Commands

```bash
# On ntp1 — confirm it has a valid time source
chronyc sources -v
chronyc tracking

# On a client — confirm it is syncing from ntp1
chronyc sources
# Should show:  ^* 10.100.1.20  ...

# Kerberos tolerance boundary test (5-minute window)
date -s "+4 min"  && kinit alice@LAB.CORP   # succeeds
date -s "+6 min"  && kinit alice@LAB.CORP   # fails
chronyc makestep  && kinit alice@LAB.CORP   # succeeds again
```

## What This Lab Teaches

- **Kerberos has a 5-minute clock skew tolerance** — NTP is not optional in an AD environment
- NTP is hierarchical: stratum 1 → stratum 2 → clients
- `chronyc sources` is the first command to run when authentication mysteriously breaks
- Time-related failures are silent and confusing — error messages rarely say "the clock is wrong"

## Experiments

- Set offsets of 3 min, 5 min, 6 min to find the exact Kerberos tolerance boundary
- Configure chrony to log to syslog, then correlate time corrections with auth failures
- Configure `dc1` as a secondary NTP server and test failover when `ntp1` is stopped
