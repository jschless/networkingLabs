# Lab 01 — Active Directory & DNS

Build the foundation of the `lab.corp` domain: a Samba AD Domain Controller providing LDAP, Kerberos, and DNS — the three services that underpin every enterprise Windows (and Linux) environment.

## Topology

```
┌─────────────────────────────────────────────────────────────┐
│                    lab-corp  10.100.0.0/16                   │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │     dc1      │  │   admin-ws   │  │     lam      │      │
│  │  Samba AD DC │  │  Workstation │  │  LDAP Account│      │
│  │ 10.100.1.10  │  │ 10.100.10.10 │  │   Manager   │      │
│  │              │  │              │  │ 10.100.1.11  │      │
│  │  LDAP :389   │  │              │  │  HTTP :80    │      │
│  │  Kerberos:88 │  │  DNS→dc1     │  │              │      │
│  │  DNS  :53    │  │              │  │  LDAP→dc1    │      │
│  │  LDAPS:636   │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `dc1` | `samba-ad:local` (custom) | `10.100.1.10` | Samba AD Domain Controller |
| `admin-ws` | `workstation:local` (custom) | `10.100.10.10` | Admin workstation with ldap-utils, krb5-user |
| `lam` | `ghcr.io/ldapaccountmanager/lam:stable` | `10.100.1.11` | LDAP Account Manager web GUI |

## Prerequisites

Build the custom images before deploying:

```bash
cd enterprise-it-101
docker compose -f labs/01-active-directory/docker-compose.yml build
```

## Deploy

```bash
cd enterprise-it-101
docker compose -f labs/01-active-directory/docker-compose.yml up -d
```

## Destroy

```bash
docker compose -f labs/01-active-directory/docker-compose.yml down -v
```

---

## What is pre-built

- Docker network `lab-corp` (10.100.0.0/16)
- Samba container with a provision script ready to run
- DNS resolution on `admin-ws` pointed at `dc1`
- LDAP Account Manager (LAM) web GUI connected to dc1

## What you configure

Everything below. AD is three services in a trenchcoat: **LDAP** (directory), **Kerberos** (authentication), and **DNS** (service location). By the end of this lab you will have provisioned all three and verified them from a client workstation.

---

## Task 1 — Provision the Domain

Shell into dc1 and run the provision script:

```bash
docker exec -it dc1 bash
bash /provision.sh
```

The script runs `samba-tool domain provision` with:

- `--realm=LAB.CORP`
- `--domain=LAB`
- `--server-role=dc`
- `--dns-backend=SAMBA_INTERNAL`

After provisioning, verify Samba is listening on the expected ports:

```bash
# Still inside dc1
ss -tlnp | grep -E '(53|88|389|445|636)'
```

??? success "Expected output"
    You should see samba listening on ports 53 (DNS), 88 (Kerberos), 389 (LDAP), 445 (SMB), and 636 (LDAPS).

---

## Task 2 — Verify DNS

From `admin-ws`, test that Samba's internal DNS is working:

```bash
docker exec -it admin-ws bash

# SOA record for the domain
dig @10.100.1.10 lab.corp SOA

# SRV records — this is how clients FIND the domain controller
dig @10.100.1.10 _ldap._tcp.lab.corp SRV
dig @10.100.1.10 _kerberos._tcp.lab.corp SRV
```

??? success "Expected output"
    The SOA query returns `dc1.lab.corp` as the primary nameserver. The SRV records point to `dc1.lab.corp` on the correct ports. These SRV records are how domain-joined machines automatically discover domain controllers — no static configuration needed.

---

## Task 3 — Create Organizational Units

OUs are containers for organizing objects in the directory. They are NOT security groups — you can't assign permissions to an OU. They exist for delegation and policy targeting.

```bash
docker exec -it dc1 bash

# Create OUs
samba-tool ou create "OU=Employees,DC=lab,DC=corp"
samba-tool ou create "OU=Workstations,DC=lab,DC=corp"
samba-tool ou create "OU=Service Accounts,DC=lab,DC=corp"

# Verify
samba-tool ou list
```

??? success "Expected output"
    ```
    OU=Employees,DC=lab,DC=corp
    OU=Workstations,DC=lab,DC=corp
    OU=Service Accounts,DC=lab,DC=corp
    OU=Domain Controllers,DC=lab,DC=corp
    ```

---

## Task 4 — Create Users

```bash
# Create users in the Employees OU
samba-tool user create alice 'P@ssw0rd1' \
    --given-name=Alice --surname=Smith \
    --userou="OU=Employees"

samba-tool user create bob 'P@ssw0rd1' \
    --given-name=Bob --surname=Jones \
    --userou="OU=Employees"

samba-tool user create charlie 'P@ssw0rd1' \
    --given-name=Charlie --surname=Brown \
    --userou="OU=Employees"

# Verify
samba-tool user list
```

??? success "Expected output"
    ```
    Administrator
    krbtgt
    Guest
    alice
    bob
    charlie
    ```

---

## Task 5 — Create Groups and Assign Membership

Groups are for permissions. OUs are for organization and policy. Don't confuse them.

```bash
# Create security groups
samba-tool group add engineering
samba-tool group add finance
samba-tool group add all-staff

# Add users to groups
samba-tool group addmembers engineering alice
samba-tool group addmembers finance bob
samba-tool group addmembers all-staff alice,bob,charlie

# Verify
samba-tool group listmembers engineering
samba-tool group listmembers finance
samba-tool group listmembers all-staff
```

??? success "Expected output"
    ```
    # engineering
    alice
    # finance
    bob
    # all-staff
    alice
    bob
    charlie
    ```

---

## Task 6 — Verify LDAP from the Workstation

From `admin-ws`, query the directory using LDAP:

```bash
docker exec -it admin-ws bash

# Anonymous bind (should show base objects)
ldapsearch -H ldap://10.100.1.10 -b "DC=lab,DC=corp" -x "(objectClass=domain)" dn

# Authenticated bind as alice
ldapsearch -H ldap://10.100.1.10 -b "DC=lab,DC=corp" \
    -D "alice@lab.corp" -w 'P@ssw0rd1' \
    "(objectClass=user)" sAMAccountName displayName memberOf
```

??? success "Expected output"
    The authenticated search returns alice, bob, charlie, Administrator, Guest, and krbtgt with their attributes. Alice's `memberOf` shows `CN=engineering` and `CN=all-staff`.

---

## Task 7 — Verify Kerberos

Kerberos is the authentication protocol. `kinit` gets a Ticket-Granting Ticket (TGT); `klist` shows your tickets.

```bash
docker exec -it admin-ws bash

# Get a Kerberos ticket for alice
kinit alice@LAB.CORP
# Enter password: P@ssw0rd1

# List tickets
klist

# Get a service ticket for LDAP
kvno ldap/dc1.lab.corp@LAB.CORP

# List tickets again — now you have a TGT and a service ticket
klist
```

??? success "Expected output"
    `klist` shows a `krbtgt/LAB.CORP@LAB.CORP` ticket (the TGT) and after `kvno`, also a `ldap/dc1.lab.corp@LAB.CORP` service ticket. Both should have a valid expiry time in the future.

---

## Task 8 — Explore with LDAP Account Manager (GUI)

In a real Windows enterprise, AD administration happens in GUI tools like Active Directory Users & Computers (ADUC). LAM provides a similar web-based experience for Samba AD.

1. Open LAM in a browser: `http://localhost:8080`
2. Log in with the LAM profile password: `lam`
3. Configure the LDAP connection:
   - Server: `ldap://dc1.lab.corp`
   - Base DN: `DC=lab,DC=corp`
4. Log in as `Administrator` with password `P@ssw0rd1`
5. Browse the OU tree — see how `OU=Employees` nests under the domain root
6. Click into alice's user object — see all LDAP attributes (`displayName`, `memberOf`, `userPrincipalName`, `objectSID`)
7. **Create a user via the GUI** (e.g., dave) — then verify via CLI:
   ```bash
   docker exec dc1 samba-tool user list
   ```

This mirrors the real-world workflow: Windows admins use ADUC daily for visual management, but automation uses PowerShell/CLI. Both perspectives matter.

---

## Verification Checklist

Run these from `admin-ws` to confirm everything works:

```bash
# DNS — SOA and SRV records
dig @10.100.1.10 lab.corp SOA +short
dig @10.100.1.10 _ldap._tcp.lab.corp SRV +short

# LDAP — authenticated search
ldapsearch -H ldap://10.100.1.10 -b "DC=lab,DC=corp" \
    -D "alice@lab.corp" -w 'P@ssw0rd1' \
    "(sAMAccountName=alice)" dn memberOf

# Kerberos — get and verify ticket
kdestroy 2>/dev/null
kinit alice@LAB.CORP      # enter password: P@ssw0rd1 when prompted
klist | grep krbtgt
```

!!! warning "Scripting `kinit`"
    MIT `kinit` reads the password from the terminal, not from a pipe — `echo 'pass' | kinit alice@LAB.CORP` will **not** authenticate. For non-interactive use, supply the credential via a keytab (`kinit -kt alice.keytab alice@LAB.CORP`) instead of piping a password.

All three should succeed. If any fail, you have a broken foundation — fix it before moving to Lab 02.

---

## Key Concepts

**AD is three services in a trenchcoat:**

| Service | Protocol | Port | Purpose |
|---------|----------|------|---------|
| Directory | LDAP | 389/636 | Stores users, groups, computers, OUs — the database |
| Authentication | Kerberos | 88 | Proves identity via tickets, not passwords on the wire |
| Service Location | DNS | 53 | SRV records tell clients where to find domain controllers |

**OUs vs Groups:**

- **OUs** are containers for organizing objects and targeting Group Policy. You can't grant file share access to an OU.
- **Groups** are for permissions. Alice is *in* the Employees OU but *a member of* the engineering group. Different things.

**SRV records are the glue:**

When a machine joins a domain or a user types `kinit alice@LAB.CORP`, the client doesn't know dc1's IP. It queries DNS for `_ldap._tcp.lab.corp` and gets back `dc1.lab.corp:389`. Delete the SRV records and the entire domain breaks.

---

## Experiments

These are optional challenges to deepen your understanding:

1. **Break DNS, break everything:** Delete the `_ldap._tcp.lab.corp` SRV record, then try `kinit` from admin-ws — watch it fail. Re-add the record and verify recovery.
   ```bash
   docker exec dc1 samba-tool dns delete dc1.lab.corp _ldap._tcp.lab.corp SRV "dc1.lab.corp 389 0 100"
   # Try kinit from admin-ws — fails
   docker exec dc1 samba-tool dns add dc1.lab.corp _ldap._tcp.lab.corp SRV "dc1.lab.corp 389 0 100"
   ```

2. **Cross-user LDAP permissions:** Can bob search for alice's attributes? What about reading `userPassword`? Test the default permission model.

3. **Create a GPO (preview of Lab 08):**
   ```bash
   docker exec dc1 samba-tool gpo create "Test Policy"
   docker exec dc1 samba-tool gpo listall
   ```

4. **Explore AD internals in LAM:** Browse `CN=Configuration,DC=lab,DC=corp` and `CN=Schema,DC=lab,DC=corp` to see AD's internal structure — sites, subnets, schema definitions.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `dig` returns SERVFAIL | Samba not running or not provisioned | Run `provision.sh`, check `supervisorctl status` |
| `kinit` returns "Cannot contact any KDC" | DNS not resolving dc1 | Check `dig @10.100.1.10 _kerberos._tcp.lab.corp SRV` |
| `kinit` returns "Pre-authentication failed" | Wrong password | Check password with `samba-tool user setpassword alice --newpassword='P@ssw0rd1'` |
| `ldapsearch` returns "Can't contact LDAP server" | Samba not listening on 389 | Check `ss -tlnp | grep 389` inside dc1 |
| LAM shows "Connection error" | Wrong LDAP URL or DC not provisioned | Verify dc1 is provisioned and check LAM config |

---

## What's Next

This lab created the identity foundation. Every subsequent lab builds on it:

- **Lab 02 (NTP)** — Time sync is required for Kerberos (5-minute tolerance)
- **Lab 03 (PKI)** — Certificates for LDAPS, HTTPS, and EAP-TLS
- **Lab 04 (Domain Join)** — Workstations authenticate against this AD
- **Labs 05-16** — Every service authenticates users against this domain controller
