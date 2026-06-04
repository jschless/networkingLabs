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

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective** and **hints** — your job is to figure out the commands. Then:

- **Predict before you run.** Each task asks you to commit to an answer first. This is the single highest-value habit in the whole lab — guessing wrong and finding out why is how the knowledge sticks.
- **Reveal the solution only after you've tried.** Commands are hidden behind `Solution` toggles. Use `samba-tool <verb> --help` and `man` first.
- **Observe, don't just verify.** The `Check your work` toggles tell you what to look for *and why it matters* — read them even when your command worked.

`samba-tool` is your primary tool on `dc1`. Almost every subcommand has `--help`. Lean on it.

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

Everything below. AD is three services in a trenchcoat: **LDAP** (directory), **Kerberos** (authentication), and **DNS** (service location). By the end of this lab you will have provisioned all three, verified them from a client workstation, broken one of them on purpose, and diagnosed the failure.

---

## Task 1 — Provision the Domain

**Objective:** Turn the bare `dc1` container into a working Active Directory Domain Controller for the realm `LAB.CORP`, then confirm the three core services are listening.

Provisioning a domain is a one-time, scripted operation (in production it's `samba-tool domain provision` or, on Windows, `dcpromo`/`Install-ADDSForest`). We've packaged it in a script so you can focus on understanding the *result*.

??? question "Predict first"
    AD bundles three services. **Before you run anything**, write down which TCP/UDP ports you expect a freshly provisioned DC to be listening on, and which service owns each. (Hint: directory, authentication, service location.)

```bash
docker exec -it dc1 bash
bash /provision.sh
```

The script runs `samba-tool domain provision` with `--realm=LAB.CORP --domain=LAB --server-role=dc --dns-backend=SAMBA_INTERNAL`, copies the generated `krb5.conf` into place, and starts Samba under supervisord.

Now confirm what's listening:

```bash
# Still inside dc1
ss -tlnp | grep -E ':(53|88|389|445|636)\b'
```

??? success "Check your work"
    You should see Samba (`samba`/`smbd`) listening on:

    | Port | Service | Why it's there |
    |------|---------|----------------|
    | 53 | DNS | Clients locate the DC and resolve names |
    | 88 | Kerberos | The KDC issues tickets |
    | 389 | LDAP | The directory itself |
    | 445 | SMB | SYSVOL / netlogon shares (Group Policy lives here) |
    | 636 | LDAPS | LDAP over TLS (we don't have a cert yet — that's Lab 03) |

    If your prediction missed 445, that's worth noting: **SMB is part of AD**, not a separate file-server thing. SYSVOL — where Group Policy is distributed — is an SMB share served by the DC.

---

## Task 2 — Discover the DC the way a client does

**Objective:** From `admin-ws`, find out where the domain controller is *without being told its IP* — using only DNS, the way a real domain-joined machine does.

A client that wants to authenticate doesn't have `dc1`'s address hard-coded. It asks DNS a very specific question. Your job is to ask DNS the same question.

??? question "Predict first"
    A laptop boots and wants to authenticate a user against `LAB.CORP`. It knows the realm name but not the DC's IP. What DNS record *type* lets a client discover "which host runs service X for this domain, and on what port"? What would the query name look like for the LDAP service?

??? note "Hints"
    - The record type is **SRV** (service location).
    - SRV query names follow the pattern `_service._protocol.domain`.
    - `dig @<dns-server> <name> <type>` queries a specific server.
    - Try both `_ldap._tcp.lab.corp` and `_kerberos._tcp.lab.corp`.

??? note "Solution"
    ```bash
    docker exec -it admin-ws bash

    # The domain's start-of-authority record — proves dc1 is authoritative for the zone
    dig @10.100.1.10 lab.corp SOA

    # Service location: where do I find LDAP and Kerberos for this realm?
    dig @10.100.1.10 _ldap._tcp.lab.corp SRV
    dig @10.100.1.10 _kerberos._tcp.lab.corp SRV
    ```

??? success "Check your work"
    The SRV answers contain four fields: **priority weight port target** — e.g. `0 100 389 dc1.lab.corp`. That last pair (`389 dc1.lab.corp`) is the entire mechanism by which a client turns "I want to talk to LDAP for LAB.CORP" into "connect to dc1.lab.corp:389".

    The priority/weight fields exist so you can run *multiple* DCs and clients will load-balance and fail over between them automatically — no client reconfiguration. This is why AD environments can add and remove DCs transparently. **Remember these SRV records — you'll deliberately break one in Task 8.**

---

## Task 3 — Design and create an OU structure

**Objective:** Create an Organizational Unit (OU) layout to hold the objects you'll create later: one for people, one for machines, one for service accounts.

??? question "Predict first"
    You'll later want to apply one Group Policy to *all workstations* and a different one to *all employees*, and you want to grant the helpdesk permission to reset employee passwords **without** giving them control of servers. Does an **OU** or a **security group** solve each of those? Why?

??? note "Hints"
    - `samba-tool ou create --help`
    - An OU's distinguished name looks like `OU=Employees,DC=lab,DC=corp`.
    - List what exists with `samba-tool ou list`.

??? note "Solution"
    ```bash
    docker exec -it dc1 bash

    samba-tool ou create "OU=Employees,DC=lab,DC=corp"
    samba-tool ou create "OU=Workstations,DC=lab,DC=corp"
    samba-tool ou create "OU=Service Accounts,DC=lab,DC=corp"

    samba-tool ou list
    ```

??? success "Check your work"
    `samba-tool ou list` shows your three OUs plus built-ins like `OU=Domain Controllers`. The DC placed *itself* in an OU at provision time — that's how a default Group Policy can target all DCs.

    Answer to the prediction: the two **policy/delegation** scenarios (GPO to all workstations, delegating password resets) are **OUs** — OUs are about *where an object lives* for the purpose of policy and administrative control. The "give a set of users access to a share" scenario is a **group**. OUs are not security principals; you cannot put an OU on an ACL.

---

## Task 4 — Create users

**Objective:** Create three employees — **alice**, **bob**, and **charlie** — inside the `Employees` OU, each with a given name and surname, password `P@ssw0rd1`.

??? question "Predict first"
    After you create exactly three users, how many entries will `samba-tool user list` show? (Trick question — think about what a freshly provisioned domain already contains.)

??? note "Hints"
    - `samba-tool user create --help` — note the positional `<username> [password]` args.
    - The flag to place a user in a specific OU is `--userou` (relative to the domain root, e.g. `--userou="OU=Employees"`).
    - `--given-name` and `--surname` set the first/last name.

??? note "Solution"
    ```bash
    samba-tool user create alice 'P@ssw0rd1' \
        --given-name=Alice --surname=Smith --userou="OU=Employees"
    samba-tool user create bob 'P@ssw0rd1' \
        --given-name=Bob --surname=Jones --userou="OU=Employees"
    samba-tool user create charlie 'P@ssw0rd1' \
        --given-name=Charlie --surname=Brown --userou="OU=Employees"

    samba-tool user list
    ```

??? success "Check your work"
    You'll see **six** entries, not three: `Administrator`, `krbtgt`, `Guest`, plus your alice/bob/charlie. The interesting one is **`krbtgt`** — that's the Kerberos service account whose key encrypts every TGT in the domain. You never log in as it, but if its password is compromised, an attacker can forge tickets for *anyone* (the infamous "Golden Ticket" attack). Provisioning a domain silently creates the entire Kerberos trust anchor.

    Confirm alice actually landed in the right OU:
    ```bash
    samba-tool user show alice | grep -i distinguishedName
    # → CN=alice,OU=Employees,DC=lab,DC=corp
    ```

---

## Task 5 — Model permissions with groups

**Objective:** Create the security groups that later labs will use for file-share and proxy access, and assign membership:

| Group | Members |
|-------|---------|
| `engineering` | alice |
| `finance` | bob |
| `all-staff` | alice, bob, charlie |

??? question "Predict first"
    alice will be a member of *two* groups. When Lab 07 grants the `engineering` group write access to a share and the `finance` group access to a different share, what determines what alice can reach — her OU, or her group memberships?

??? note "Hints"
    - `samba-tool group add <name>` creates a group.
    - `samba-tool group addmembers <group> <user1>,<user2>` adds members (comma-separated, no spaces).
    - Verify with `samba-tool group listmembers <group>`.

??? note "Solution"
    ```bash
    samba-tool group add engineering
    samba-tool group add finance
    samba-tool group add all-staff

    samba-tool group addmembers engineering alice
    samba-tool group addmembers finance bob
    samba-tool group addmembers all-staff alice,bob,charlie

    samba-tool group listmembers engineering
    samba-tool group listmembers finance
    samba-tool group listmembers all-staff
    ```

??? success "Check your work"
    `engineering` → alice, `finance` → bob, `all-staff` → all three. Group membership — not OU placement — is what gets evaluated against a resource's ACL. alice lives in one OU (`Employees`) but draws permissions from two groups. **This separation is the whole point:** organization (OU) and authorization (group) are deliberately different axes so you can reorganize people without rewriting permissions, and vice versa.

---

## Task 6 — Inspect the directory with LDAP (anonymous vs. authenticated)

**Objective:** Query the directory two ways — once with no credentials, once as alice — and **explain the difference in what you can see.** This is the lab's lesson on directory access control.

??? question "Predict first"
    Will an *anonymous* (unauthenticated) LDAP query be able to read alice's group memberships? Her password hash? Will an *authenticated* query as alice be able to read bob's password hash? Commit to yes/no for each before running.

??? note "Hints"
    - `ldapsearch -x` does an anonymous (simple) bind; `-D <binddn> -w <password>` binds as a user.
    - `-H ldap://10.100.1.10` sets the server, `-b "DC=lab,DC=corp"` the search base.
    - Bind DN for alice can be her UPN: `alice@lab.corp`.
    - Try requesting specific attributes: `... sAMAccountName memberOf unicodePwd`.

??? note "Solution"
    ```bash
    docker exec -it admin-ws bash

    # 1) Anonymous — what can a stranger on the network read?
    ldapsearch -x -H ldap://10.100.1.10 -b "DC=lab,DC=corp" \
        "(sAMAccountName=alice)" sAMAccountName memberOf

    # 2) Authenticated as alice — what can a logged-in user read?
    ldapsearch -H ldap://10.100.1.10 -b "DC=lab,DC=corp" \
        -D "alice@lab.corp" -w 'P@ssw0rd1' \
        "(sAMAccountName=alice)" sAMAccountName memberOf

    # 3) Try to read a password attribute as alice — note what comes back
    ldapsearch -H ldap://10.100.1.10 -b "DC=lab,DC=corp" \
        -D "alice@lab.corp" -w 'P@ssw0rd1' \
        "(sAMAccountName=bob)" unicodePwd
    ```

??? success "Check your work"
    - **Anonymous** binds against AD return little or nothing — modern AD disables anonymous reads of user objects by default. If you got an empty/`operationsError` result, that's correct and *good*: a stranger shouldn't enumerate your directory.
    - **Authenticated as alice**, you can read normal attributes (`memberOf`, `displayName`) for users across the directory — ordinary users can *read* most of the directory.
    - **No one** gets `unicodePwd` back over LDAP — password material is never returned, even to an authenticated bind, even for your own account. Authorization in AD is per-attribute, not just per-object. This is why "I can see the user exists" and "I can read their secrets" are completely different privileges.

---

## Task 7 — Watch Kerberos actually work

**Objective:** Authenticate as alice, then **inspect the ticket cache** to see the difference between a Ticket-Granting Ticket (TGT) and a service ticket. Then capture the authentication on the wire to confirm the password is never sent.

This is the heart of the lab. Don't just run the commands — *read the ticket cache* and *read the capture*.

??? question "Predict first"
    1. Right after `kinit`, how many tickets are in your cache, and for which principal(s)?
    2. After you then request a service ticket for LDAP, how many will there be?
    3. When you `kinit`, does your password (or its hash) travel across the network to the KDC?

??? note "Hints"
    - `kinit <user>@LAB.CORP` gets a TGT (it will prompt for the password).
    - `klist` shows the cache; look at the **service principal** column.
    - `kvno <service>/<host>@REALM` forces acquisition of a service ticket, e.g. `kvno ldap/dc1.lab.corp@LAB.CORP`.
    - To capture: run `tcpdump -n -i any port 88 -w /tmp/krb.pcap` in one shell, `kinit` in another, then read it back with `tcpdump -r /tmp/krb.pcap -A` or `-X`.

??? note "Solution"
    ```bash
    docker exec -it admin-ws bash

    kdestroy 2>/dev/null                 # start clean
    kinit alice@LAB.CORP                 # enter P@ssw0rd1 when prompted
    klist                                # observe: one ticket — the TGT

    kvno ldap/dc1.lab.corp@LAB.CORP      # ask for a service ticket
    klist                                # observe: now TWO tickets
    ```

    Capture the exchange (two shells into admin-ws, or background the capture):
    ```bash
    kdestroy
    tcpdump -n -i any port 88 -w /tmp/krb.pcap &
    kinit alice@LAB.CORP
    kill %1
    tcpdump -r /tmp/krb.pcap -A | grep -i -E 'P@ssw0rd1|alice' || echo "password NOT found in cleartext"
    ```

??? success "Check your work"
    - After `kinit`: **one** ticket, `krbtgt/LAB.CORP@LAB.CORP` — the TGT. This is your "I proved who I am" token.
    - After `kvno`: **two** tickets — the TGT plus `ldap/dc1.lab.corp@LAB.CORP`. You authenticated *once* (kinit) and now obtain per-service tickets *without re-entering your password*. That is single sign-on, and it's the entire reason Kerberos exists.
    - The grep for your password should find **nothing**. Kerberos never transmits the password; the client proves knowledge of the password-derived key by encrypting a timestamp. You may see the principal name `alice` (that's not secret) but never `P@ssw0rd1`. This is the concrete payoff of "tickets, not passwords on the wire."

    Look at the ticket lifetimes in `klist` too — TGTs expire (often 10h) and must be renewed. A stolen ticket is only useful until it expires; a stolen password is useful until it's changed.

---

## Task 8 — Break it: kill service location and diagnose

**Objective (required):** Delete the `_ldap._tcp` SRV record, observe a realistic failure, **diagnose it from symptoms alone**, then repair it. This is the most important task in the lab — every Tasks-1-7 success depended on this record working, and now you'll see what its absence looks like from the client's seat.

??? question "Predict first"
    If you delete the SRV record that tells clients where to find LDAP/Kerberos, what *error message* will `kinit` produce on admin-ws? Will it be an obvious "DNS is broken" message, or something that looks like an authentication problem? Predict the wording.

**Break it** (on dc1). `delete` must match the record *exactly*, so query it first to get the real priority/weight:
```bash
docker exec -it dc1 bash

# See the exact record data — fields are: target port priority weight
samba-tool dns query 127.0.0.1 lab.corp _kerberos._tcp SRV -U Administrator
# e.g. it prints "dc1.lab.corp 88 0 100" — use whatever YOUR DC shows below

# samba-tool DNS SRV data format is: "target port priority weight"
samba-tool dns delete dc1.lab.corp _kerberos._tcp.lab.corp SRV "dc1.lab.corp 88 0 100" -U Administrator
# (enter P@ssw0rd1 if prompted)
```

**Now diagnose from the client**, as if you didn't know what changed:
```bash
docker exec -it admin-ws bash
kdestroy 2>/dev/null
kinit alice@LAB.CORP        # observe the failure
```

??? note "Diagnosis hints (try before revealing)"
    - Did `kinit` say anything about *authentication*, or about *contacting a KDC*?
    - Our `/etc/krb5.conf` on admin-ws hard-codes `kdc = dc1.lab.corp`, so this particular client may still work — if so, that itself is a lesson. Test discovery directly instead of trusting it:
      ```bash
      dig @10.100.1.10 _kerberos._tcp.lab.corp SRV     # compare to Task 2's answer
      ```
    - A machine *without* a hard-coded KDC (the normal case, set via DHCP/realm join) relies entirely on this SRV record. What happens to it?

??? success "What you should observe"
    `dig` now returns **no SRV answer** for `_kerberos._tcp.lab.corp`. On a client relying on DNS discovery, `kinit` fails with `kinit: Cannot find KDC for realm "LAB.CORP"` — note that this reads like a *Kerberos* problem, but the root cause is *DNS*. This symptom/cause mismatch is the #1 reason AD outages are misdiagnosed.

    Because our lab workstation has `kdc = dc1.lab.corp` pinned in `/etc/krb5.conf`, *its* `kinit` may still succeed even with the SRV record gone — demonstrating exactly why hard-coding works around the symptom but hides the disease. In production almost nothing hard-codes the KDC, so this record is load-bearing for the entire domain.

**Repair it:**
```bash
docker exec -it dc1 bash
samba-tool dns add dc1.lab.corp _kerberos._tcp.lab.corp SRV "dc1.lab.corp 88 0 100" -U Administrator
# verify from admin-ws:
docker exec -it admin-ws dig @10.100.1.10 _kerberos._tcp.lab.corp SRV +short
```

---

## Task 9 — Explore with LDAP Account Manager (GUI)

**Objective:** Cross-check your CLI work in a visual directory browser, and create one object via the GUI to feel the difference.

In a real Windows enterprise, AD administration happens in GUI tools like Active Directory Users & Computers (ADUC). LAM is the open-source equivalent for Samba AD.

1. Open LAM: `http://localhost:8080` — log in with the LAM profile password `lam`.
2. Point it at `ldap://dc1.lab.corp`, base DN `DC=lab,DC=corp`, and authenticate as `Administrator` / `P@ssw0rd1`.
3. Browse the OU tree — find alice under `OU=Employees` and confirm it matches the DN you saw in Task 4.
4. Open alice's object and find the attributes you queried over LDAP in Task 6 (`memberOf`, `userPrincipalName`, `objectSID`). Notice the GUI shows you the *whole* attribute set at a glance.
5. **Create a user `dave` via the GUI**, then drop to the CLI and prove it took:
   ```bash
   docker exec dc1 samba-tool user show dave | grep -i distinguishedName
   ```

The GUI and CLI operate on the *same* directory — there's no separate database. Windows admins click in ADUC daily but automate with PowerShell/CLI; both are views onto one LDAP tree.

---

## Verification Checklist

Run these from `admin-ws` to confirm the foundation is solid before moving to Lab 02:

```bash
# DNS — SOA and SRV records resolve
dig @10.100.1.10 lab.corp SOA +short
dig @10.100.1.10 _ldap._tcp.lab.corp SRV +short
dig @10.100.1.10 _kerberos._tcp.lab.corp SRV +short

# LDAP — authenticated search returns alice with her groups
ldapsearch -H ldap://10.100.1.10 -b "DC=lab,DC=corp" \
    -D "alice@lab.corp" -w 'P@ssw0rd1' \
    "(sAMAccountName=alice)" dn memberOf

# Kerberos — get a TGT and confirm it's cached
kdestroy 2>/dev/null
kinit alice@LAB.CORP      # enter password: P@ssw0rd1 when prompted
klist | grep krbtgt
```

!!! warning "Scripting `kinit`"
    MIT `kinit` reads the password from the terminal, not from a pipe — `echo 'pass' | kinit alice@LAB.CORP` will **not** authenticate. For non-interactive use, supply the credential via a keytab (`kinit -kt alice.keytab alice@LAB.CORP`) instead of piping a password.

All three pillars should succeed. If any fail, you have a broken foundation — fix it before moving on.

---

## Challenge Questions

No solutions are given for these — they test whether you can *reason* about the system, not recall commands. Write your answers down; you'll validate them in later labs.

1. **The dependency chain.** Rank DNS, Kerberos, and LDAP by "what breaks first." If DNS is down, which of the other two still work? If Kerberos is down but DNS and LDAP are up, can a user log in? Justify the ordering.

2. **Diagnose from a symptom.** A user reports: *"I can `kinit` fine, but when I try to access a file share I get `Cannot find KDC for realm`."* Authentication clearly worked a second ago. List three specific things you would check, and explain what each would tell you. (Hint: think about what's different between getting a TGT and getting a *service* ticket.)

3. **OU vs. group, for real.** The helpdesk should be able to reset passwords for everyone in `Employees` but must never touch service accounts. The `engineering` team should have write access to a code repository share. Which of these is an OU/delegation problem and which is a group/ACL problem? Could you solve either one with the *other* mechanism, and what would go wrong if you tried?

4. **Golden ticket.** Given what you saw in Task 4 about `krbtgt`, explain in two sentences why an attacker who steals the `krbtgt` key can impersonate any user — and why simply resetting one user's password does nothing to stop them.

5. **Design extension.** You're asked to add a second domain controller (`dc2`) for redundancy. Based on what you learned in Task 2 about SRV records, what would clients need to do to start using `dc2` automatically? (Answer: nothing — explain why.)

---

## Key Concepts

**AD is three services in a trenchcoat:**

| Service | Protocol | Port | Purpose |
|---------|----------|------|---------|
| Directory | LDAP | 389/636 | Stores users, groups, computers, OUs — the database |
| Authentication | Kerberos | 88 | Proves identity via tickets, not passwords on the wire |
| Service Location | DNS | 53 | SRV records tell clients where to find domain controllers |

**OUs vs Groups:**

- **OUs** are containers for organizing objects and targeting Group Policy / delegation. You can't grant file-share access to an OU.
- **Groups** are security principals for permissions. Alice is *in* the Employees OU but *a member of* the engineering group. Different axes, different purposes.

**SRV records are the glue:**

When a machine joins a domain or a user runs `kinit alice@LAB.CORP`, the client doesn't know dc1's IP. It queries DNS for `_kerberos._tcp.lab.corp` / `_ldap._tcp.lab.corp` and gets back `dc1.lab.corp` plus a port. Delete those records (Task 8) and clients relying on discovery lose the entire domain — while the error blames Kerberos, not DNS.

**Tickets, not passwords:**

`kinit` proves you know your password *without sending it*. You get a TGT, then trade it for per-service tickets — that's single sign-on, and it's why a stolen ticket (time-limited) is less catastrophic than a stolen password (valid until changed). The `krbtgt` account's key underwrites all of it.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `bash /provision.sh` errors, or `supervisorctl` can't connect | supervisord not up | `supervisorctl status`; check `/var/log/supervisor/` |
| `dig` returns SERVFAIL | Samba not running or not provisioned | Run `provision.sh`, check `supervisorctl status` |
| `kinit` returns "Cannot find/contact any KDC" | DNS SRV missing or unreachable (see Task 8) | `dig @10.100.1.10 _kerberos._tcp.lab.corp SRV` |
| `kinit` returns "Pre-authentication failed" | Wrong password | `samba-tool user setpassword alice --newpassword='P@ssw0rd1'` |
| `ldapsearch` returns "Can't contact LDAP server" | Samba not listening on 389 | `ss -tlnp \| grep 389` inside dc1 |
| Anonymous `ldapsearch` returns nothing | Working as intended | AD disables anonymous reads — bind as a user |
| LAM shows "Connection error" | Wrong LDAP URL or DC not provisioned | Verify dc1 is provisioned and check LAM config |

---

## What's Next

This lab created the identity foundation. Every subsequent lab builds on it:

- **Lab 02 (NTP)** — Time sync is required for Kerberos (5-minute tolerance). You'll skew the clock and watch `kinit` break — a different failure mode from Task 8's DNS break.
- **Lab 03 (PKI)** — Certificates for LDAPS (port 636, which you saw listening but couldn't use yet), HTTPS, and EAP-TLS.
- **Lab 04 (Domain Join)** — Workstations authenticate against this AD using the same SRV discovery you did by hand in Task 2.
- **Labs 05-16** — Every service authenticates users against this domain controller.
