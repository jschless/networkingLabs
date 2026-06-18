# Lab 04 — Domain Join & Identity

**Duration:** 2–3 hours

In Labs 01–03 you built the domain and queried it as an outsider — `kinit` and `ldapsearch` from a workstation that wasn't *part* of the domain. This lab makes a Linux machine a real **domain member**: you create its computer account in AD, wire up `sssd` so AD users can log in with their domain passwords, enforce access by AD group, and then pull the network out from under it to discover what `sssd`'s credential cache does (and what it costs). By the end you'll understand that "domain join" is not magic — it's a machine account, a keytab, and three providers (`id`, `auth`, `access`) all pointed at the DC.

## Topology

```
┌────────────────────────────────────────────────────────────────────┐
│                       lab-corp  10.100.0.0/16                      │
│                                                                    │
│   ┌──────────────┐        ┌──────────────┐     ┌──────────────┐    │
│   │     dc1      │◀───────│     ws1      │     │     ws2      │    │
│   │  Samba AD DC │  join  │ Workstation  │     │ Workstation  │    │
│   │ 10.100.1.10  │◀───────│ 10.100.10.11 │     │ 10.100.10.12 │    │
│   │              │  LDAP/ │  sssd → AD   │     │  sssd → AD   │    │
│   │  KDC + LDAP  │  Krb5  │ (WS1$ acct)  │     │ (WS2$ acct)  │    │
│   └──────────────┘        └──────────────┘     └──────────────┘    │
│        AD users (alice/bob/charlie) log in on either workstation   │
└────────────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `dc1` | `samba-ad:local` | `10.100.1.10` | Samba AD DC (auto-provisioned) |
| `ws1` | `workstation:local` | `10.100.10.11` | Workstation to join (starts **unjoined**) |
| `ws2` | `workstation:local` | `10.100.10.12` | Second workstation to join |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective** and **hints** — your job is to figure out the commands. Predict before you run, reveal the solution only after you've tried, and read the `Check your work` toggles for *why*, not just *whether*.

!!! warning "Test logins from an UNPRIVILEGED shell"
    `docker exec` drops you in as **root**, and root's `su` switches user
    *without checking a password*. So `su - alice` as root proves nothing about
    authentication. The wire-up step creates a normal local user `tester`; do
    your login tests as `tester` (`docker exec -it ws1 su - tester`, then
    `su - alice@lab.corp`). Only then is the AD password actually enforced.

!!! note "We use `adcli`, not `realm join`"
    `realm join` is the usual one-liner, but it drives `realmd` over D-Bus and
    finishes by enabling `sssd` through **systemd** — neither of which runs in a
    plain container. So we run the steps `realm join` *would* run, directly:
    `adcli join` (create the machine account) + an `sssd.conf` + PAM/NSS wiring.
    This is more honest — you see exactly what a join consists of.

## Prerequisites

- **Labs 01–03** concepts. You don't need them running — `dc1` auto-provisions and seeds `alice`/`bob`/`charlie` and the `engineering`/`finance`/`all-staff` groups.
- The custom images built:

```bash
cd enterprise-it-101
docker build -t samba-ad:local   images/samba-ad/
docker build -t workstation:local images/workstation/
```

## Deploy

```bash
cd enterprise-it-101
docker compose -f base/docker-compose.yml \
               -f labs/04-domain-join/docker-compose.override.yml up -d
```

## Destroy

```bash
docker compose -f base/docker-compose.yml \
               -f labs/04-domain-join/docker-compose.override.yml down -v
```

---

## What is pre-built

- The `lab.corp` domain (auto-provisioned, seeded) on `dc1`.
- `ws1` and `ws2`, **unjoined**, with DNS pointed at `dc1`, a Kerberos config, a ready-to-use `sssd.conf` (mounted at `/etc/sssd/sssd.conf.lab`), and a wiring helper (`/usr/local/bin/wire-up-sssd.sh`).

## What you configure

You join `ws1` to the domain, make it use AD for identity and login, log in as AD users, enforce sudo by AD group, then break and diagnose offline authentication — and finally join `ws2` to see the domain track multiple machines.

---

## Task 1 — Confirm `ws1` is an outsider

**Objective:** Establish the baseline: `ws1` can *find* the domain but knows nothing about its users yet.

??? question "Predict first"
    `ws1`'s DNS already points at `dc1`, so it can resolve the domain and its SRV records. Does that mean `id alice@lab.corp` will return alice's identity? Why or why not — what's the difference between *finding* the DC and *trusting* it for identity?

??? note "Hints"
    - `getent hosts dc1.lab.corp` and `dig +short @10.100.1.10 _ldap._tcp.lab.corp SRV` show discovery works.
    - `id alice@lab.corp` asks NSS to resolve an AD user.

??? note "Solution"
    ```bash
    docker exec ws1 getent hosts dc1.lab.corp
    docker exec ws1 dig +short @10.100.1.10 _ldap._tcp.lab.corp SRV
    docker exec ws1 id alice@lab.corp        # expect: no such user
    ```

??? success "Check your work"
    DNS resolves `dc1` and returns the LDAP SRV record (`0 100 389 dc1.lab.corp`), but `id alice@lab.corp` fails with **`no such user`**. That's the whole point of the lab: a machine can *reach* the directory and still have no idea who's in it, because nothing on `ws1` is configured to *ask* AD for identities. Discovery (DNS) and membership (a configured, trusted relationship) are different things — you supply the second over the next two tasks.

---

## Task 2 — Join the domain (create the machine account)

**Objective:** Create `ws1`'s computer account in AD with `adcli`, and inspect the two things a join actually produces: an object in the directory and a keytab on disk.

??? question "Predict first"
    A *user* proves identity with a password. After `ws1` joins, *the machine* needs to prove its own identity to AD (to look users up securely, validate logins, etc.). It has no human to type a password. So what credential does the join create for the machine, and where does it live?

??? note "Hints"
    - `adcli join lab.corp -U Administrator` creates the account (it'll prompt for the Administrator password, `P@ssw0rd1`; `--stdin-password` lets you pipe it).
    - After joining: on `dc1`, `samba-tool computer list` and `samba-tool computer show WS1`.
    - On `ws1`, the machine's Kerberos keys land in a **keytab**: `klist -k /etc/krb5.keytab`.

??? note "Solution"
    ```bash
    docker exec -it ws1 adcli join lab.corp -U Administrator
    # password: P@ssw0rd1

    # What the join created in the directory:
    docker exec dc1 samba-tool computer list
    docker exec dc1 samba-tool computer show WS1

    # What it created on the machine:
    docker exec ws1 klist -k /etc/krb5.keytab
    ```

??? success "Check your work"
    `samba-tool computer list` now shows **`WS1$`** alongside `DC1$` (the trailing `$` marks a machine account). `samba-tool computer show WS1` reveals it's a real directory object — `objectClass: computer`, `sAMAccountName: WS1$`, `dNSHostName`, and `servicePrincipalName: host/WS1`. On `ws1`, `klist -k` lists machine principals (`WS1$@LAB.CORP`, `host/WS1@LAB.CORP`) in `/etc/krb5.keytab`.

    Your prediction: the machine's credential is a **keytab** — a file of Kerberos keys for the machine account, the password-less equivalent of a user's password. That's how `sssd` will authenticate *as the machine* to AD without anyone typing anything. The machine account is also why a stolen/cloned VM is a security problem: it carries a valid domain credential.

---

## Task 3 — Make `ws1` use AD for identity

**Objective:** Point NSS and PAM at `sssd`, start `sssd`, and confirm AD users now resolve. Understand what the `sssd.conf` directives decide.

The mounted `sssd.conf` is the file `realm join` would have generated. **Read it** — `docker exec ws1 cat /etc/sssd/sssd.conf.lab` — before you run anything.

??? question "Predict first"
    `sssd.conf` sets `ldap_id_mapping = True`. AD identifies users by SID, but Linux needs a numeric UID. With this setting on, where does alice's UID come from — is it stored in AD, or computed on the client? And what would happen to file ownership if two machines computed it *differently*?

??? note "Hints"
    - The wiring (install `sssd.conf` with `0600` perms, set `nsswitch.conf` to use `sss`, enable `pam_sss` + `pam_mkhomedir`, start `sssd`) is boilerplate — run the helper: `bash /usr/local/bin/wire-up-sssd.sh`.
    - Then `id alice@lab.corp` and `getent passwd alice@lab.corp`.
    - The three providers in `sssd.conf` — `id_provider`, `auth_provider`, `access_provider` — map to "who are you / prove it / may you log in."

??? note "Solution"
    ```bash
    docker exec ws1 cat /etc/sssd/sssd.conf.lab       # read it first
    docker exec ws1 bash /usr/local/bin/wire-up-sssd.sh
    sleep 4
    docker exec ws1 id alice@lab.corp
    docker exec ws1 getent passwd alice@lab.corp
    docker exec ws1 getent group engineering@lab.corp
    ```

??? success "Check your work"
    `id alice@lab.corp` now returns a UID/GID and her group memberships (`domain users`, `engineering`, `all-staff`); `getent` shows her home as `/home/alice@lab.corp` and shell `/bin/bash`. Nothing about alice is stored locally — every lookup goes NSS → `sssd` → AD over LDAP.

    Your prediction: with `ldap_id_mapping = True`, the UID is **computed on the client** by hashing the user's SID into a numeric range — *not* stored in AD. Because the algorithm is deterministic, every correctly-configured member computes the *same* UID, so alice owns her files consistently across machines. If one host used a different mapping (e.g. rfc2307 `uidNumber` attributes, or a different range), her files would appear owned by the wrong user there — the classic "NFS home directory shows the wrong owner" bug.

---

## Task 4 — Log in as an AD user

**Objective:** Authenticate as alice using her AD password (from an unprivileged shell), watch her home directory get created, and prove the password is actually checked by AD.

??? question "Predict first"
    alice has never logged into `ws1`, so `/home/alice@lab.corp` doesn't exist. When she logs in, who creates it — AD, or something on `ws1`? And if you type the *wrong* password, which component says no: `ws1` or `dc1`?

??? note "Hints"
    - Become the unprivileged `tester` first (root's `su` skips passwords): `docker exec -it ws1 su - tester`.
    - From `tester`'s shell: `su - alice@lab.corp` (enter `P@ssw0rd1`). Then `whoami`, `pwd`, `ls -ld /home/alice@lab.corp`.
    - Try a wrong password too, and read the failure.

??? note "Solution"
    ```bash
    docker exec -it ws1 su - tester
    # now you are 'tester' (unprivileged):
    su - alice@lab.corp        # enter P@ssw0rd1  -> succeeds
    whoami; pwd
    exit
    su - alice@lab.corp        # enter a WRONG password -> Authentication failure
    exit
    exit
    ```

??? success "Check your work"
    With the right password the login succeeds, `whoami` is `alice@lab.corp`, and her home directory `/home/alice@lab.corp` now exists (created at login). With a wrong password you get `su: Authentication failure`.

    Your prediction: the home directory is created by **`pam_mkhomedir` on `ws1`** during the session phase — AD has no idea about Linux home directories. The password is checked by **`dc1`** (Kerberos), because `auth_provider = ad`; `ws1` just relays the credential. This split — `ws1` does local session setup, `dc1` does authentication — is the essence of `pam_sss`: PAM and NSS on the client, the actual identity and secret on the DC.

---

## Task 5 — Switch to short usernames

**Objective:** Reconfigure `sssd` so users log in as `alice` instead of `alice@lab.corp`, and understand why the fully-qualified form is the safer default.

??? question "Predict first"
    Logging in as `alice@lab.corp` is verbose. You can set `use_fully_qualified_names = False` for short names. In a domain with a *single* realm that's harmless — but what specific collision does the fully-qualified form prevent in an environment with **two** trusted domains?

??? note "Hints"
    - Edit `/etc/sssd/sssd.conf` (the live file, not the `.lab` reference): set `use_fully_qualified_names = False`.
    - `sssd` caches aggressively — after a config change, clear the cache and restart it: `sss_cache -E`, then `pkill -x sssd; sssd`.
    - Test `id alice` and a `tester` → `su - alice` login.

??? note "Solution"
    ```bash
    docker exec ws1 sed -i \
      's/^use_fully_qualified_names = True/use_fully_qualified_names = False/' \
      /etc/sssd/sssd.conf
    docker exec ws1 bash -c 'sss_cache -E; pkill -x sssd; sleep 1; sssd; sleep 4'
    docker exec ws1 id alice
    docker exec -it ws1 su - tester -c 'su - alice'   # P@ssw0rd1
    ```

??? success "Check your work"
    `id alice` (short name) now resolves, and login as `alice` works. Your prediction: fully-qualified names prevent **username collisions across domains** — if `ws1` trusted both `lab.corp` and, say, `acme.corp`, and both had an `alice`, the short name `alice` is ambiguous; `alice@lab.corp` vs `alice@acme.corp` is not. That's why `use_fully_qualified_names = True` is the safe default and short names are a single-domain convenience.

---

## Task 6 — Authorize sudo by AD group

**Objective:** Grant sudo to the `engineering` group (an AD group), and confirm a non-member is denied — authorization driven entirely by directory membership.

??? question "Predict first"
    You'll grant sudo to `%engineering`. alice is in `engineering`; bob is in `finance`. Without touching `ws1` again, if you later move alice *out* of `engineering` in AD, does her sudo access disappear — and what would you have to do on `ws1`, if anything, for the change to take effect?

??? note "Hints"
    - A sudoers drop-in: `/etc/sudoers.d/engineering` containing `%engineering ALL=(ALL:ALL) ALL` (mode `0440`). The `%` means "group."
    - Check effective privileges without logging in: `sudo -l -U alice` and `sudo -l -U bob`.

??? note "Solution"
    ```bash
    docker exec ws1 bash -c 'echo "%engineering ALL=(ALL:ALL) ALL" > /etc/sudoers.d/engineering; chmod 440 /etc/sudoers.d/engineering'
    docker exec ws1 sudo -l -U alice     # may run (ALL : ALL) ALL
    docker exec ws1 sudo -l -U bob       # not allowed
    ```

??? success "Check your work"
    `sudo -l -U alice` reports `User alice may run … (ALL : ALL) ALL`; `sudo -l -U bob` reports `User bob is not allowed to run sudo`. The sudoers rule references an **AD group**, resolved live through `sssd` — you never list individual users.

    Your prediction: moving alice out of `engineering` in AD **does** remove her sudo — but not instantly, because `sssd` caches group membership. The change takes effect after the cache refreshes (or immediately if you run `sss_cache -E`). This is the power and the hazard of directory-driven authorization: one change in AD reshapes access on every member — on the cache's schedule, not necessarily the instant you click save.

---

## Task 7 — Break it: pull the network and meet the cache

**Objective (required Break-It):** Discover `sssd`'s offline credential cache by taking the DC away. See who can still log in and who can't, diagnose the failure, then recover.

??? question "Predict first"
    alice logged in earlier (Task 4/5); charlie never has. If you **stop `dc1`** and then try to log in as each: predict who succeeds and who fails, and *why the difference*. (Then predict the security implication: if an admin disables alice's account in AD while `dc1` is reachable, can a stolen, offline laptop still log her in?)

**Set the cache, then break it:**

```bash
# alice logs in while ONLINE so her credential is cached:
docker exec -it ws1 su - tester -c 'su - alice'      # P@ssw0rd1, then exit, exit

# pull the DC:
docker stop dc1
sleep 8
```

**Now diagnose from `ws1`:**

```bash
# cached user, DC down:
docker exec -it ws1 su - tester -c 'su - alice'      # P@ssw0rd1
# never-logged-in user, DC down:
docker exec -it ws1 su - tester -c 'su - charlie'    # P@ssw0rd1
```

??? note "Diagnosis hints (try before revealing)"
    - One login works and one fails. The failing one isn't "wrong password" — read the exact message.
    - `cache_credentials = True` in `sssd.conf` is the clue. What can `sssd` answer from cache, and what does it *have* to ask the DC for?

??? success "What you should observe"
    alice logs in **successfully** even with `dc1` down; charlie fails with `su: user charlie does not exist or the user entry does not contain all the required fields`. The difference: `sssd` cached alice's identity *and* credential when she logged in online, so it can authenticate her offline. charlie was never cached, so with the DC unreachable `sssd` can't even resolve him, let alone check his password.

    This is exactly why a domain laptop still logs you in on a plane: `sssd` (like Windows' cached domain logon) keeps the last successful credential. The security flip-side answers the prediction: **a disabled AD account can still log in on an offline machine from cache** until that machine next reaches the DC — which is why "disable the account" must be paired with "and confirm the endpoint has checked in," and why cached-credential lifetime is a real policy knob.

**Repair it** — bring the DC back and clear `sssd`'s offline/negative cache so it goes back online cleanly:

```bash
docker start dc1
sleep 12
docker exec ws1 bash -c 'sss_cache -E; pkill -x sssd; sleep 1; sssd; sleep 6'
docker exec -it ws1 su - tester -c 'su - charlie'    # now succeeds, and is cached
```

---

## Task 8 — Join `ws2` and see the domain track both

**Objective:** Repeat the join on `ws2` and confirm AD now tracks two member machines.

??? note "Hints"
    - Same as Tasks 2–3: `adcli join` then `wire-up-sssd.sh`.
    - On `dc1`: `samba-tool computer list`.

??? note "Solution"
    ```bash
    docker exec -it ws2 adcli join lab.corp -U Administrator      # P@ssw0rd1
    docker exec ws2 bash /usr/local/bin/wire-up-sssd.sh
    docker exec ws2 id alice@lab.corp
    docker exec dc1 samba-tool computer list                       # WS1$, WS2$, DC1$
    ```

??? success "Check your work"
    `samba-tool computer list` shows `WS1$`, `WS2$`, and `DC1$`. Both workstations now authenticate the same AD users with the same UIDs (thanks to `ldap_id_mapping`), and the domain has a directory object per machine — the foundation for targeting configuration (Lab 08) and tracking endpoints (Lab 14) at scale.

---

## Verification Checklist

```bash
# Both machines are joined
docker exec dc1 samba-tool computer list                         # WS1$  WS2$  DC1$

# ws1 resolves AD identity and group membership
docker exec ws1 id alice@lab.corp

# AD authentication is enforced (from an unprivileged shell, right password)
docker exec -it ws1 su - tester -c 'su - alice@lab.corp -c whoami'   # alice@lab.corp

# Group-based authorization
docker exec ws1 sudo -l -U alice | grep -i 'may run'             # allowed
docker exec ws1 sudo -l -U bob                                   # not allowed
```

---

## Challenge Questions

No solutions provided — reason it through.

1. **The dependency stack.** A user reports they can't log into `ws1` this morning. List, in order, the four things that must be working for an AD login to succeed (think DNS → time → the machine's own credential → the DC). For each, name one command on `ws1` that would confirm or eliminate it. (This is the diagnostic ladder for every "can't log in" ticket.)

2. **Cache as asset and liability.** Give one scenario where `sssd`'s credential cache saves the day and one where it's a security hole. What single `sssd.conf` setting would you tune to bound the risk, and what usability cost does tightening it impose?

3. **Identity mapping gone wrong.** `ws1` uses `ldap_id_mapping = True`; a new file server is set up with rfc2307 `uidNumber` attributes instead. alice's files on the new server show as owned by `nobody` or a stranger. Explain the root cause and two ways to fix it consistently across the fleet.

4. **What does the keytab really protect?** The machine keytab `/etc/krb5.keytab` lets `ws1` prove it's `WS1$`. If an attacker copies that file off a decommissioned-but-not-removed machine, what can they do, and what AD-side action neutralises a stolen machine credential? (Contrast with neutralising a stolen *user* password.)

5. **Design extension (previews Lab 08).** Now that `ws1`/`ws2` are computer objects in an OU, you want to push a uniform SSH banner and NTP config to all workstations. Sketch how you'd target "all machines in the Workstations OU" — and why directory membership (not a hand-maintained host list) is the thing you target.

---

## Key Concepts

**A domain join is three concrete artifacts:**

| Artifact | Where | Purpose |
|----------|-------|---------|
| Computer account (`WS1$`) | In AD | The directory tracks the machine as a principal |
| Keytab (`/etc/krb5.keytab`) | On the host | The machine's password-less credential to AD |
| `sssd.conf` + PAM/NSS | On the host | Wires Linux identity/login to the DC |

**`sssd`'s three providers:**

- `id_provider = ad` — *who are you?* (users/groups via LDAP; `ldap_id_mapping` computes POSIX UIDs from SIDs client-side, deterministically)
- `auth_provider = ad` — *prove it* (password checked by the KDC via Kerberos)
- `access_provider = ad` — *may you log in here?* (AD-side access control)

**PAM vs NSS vs sssd:** NSS answers "does this user exist / what's their UID" (`id`, `getent`); PAM answers "may this user log in right now" (`su`, `login`) via `pam_sss`; `sssd` is the daemon both consult, and the only thing that talks to AD. `pam_mkhomedir` (local) creates the home directory; AD never does.

**The credential cache** (`cache_credentials = True`) lets a member authenticate a *previously-seen* user while the DC is unreachable — offline laptop logins — at the cost that disabled accounts may still work offline until the machine checks in.

**Root's `su` skips authentication** — always test logins from an unprivileged shell, or you're testing nothing.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `adcli join` → `Couldn't authenticate` | Wrong admin password or clock skew (Lab 02!) | Use `P@ssw0rd1`; check time is within 5 min |
| `id alice@lab.corp` → `no such user` | `sssd` not running, or NSS not pointed at `sss` | Run `wire-up-sssd.sh`; check `/etc/nsswitch.conf` |
| `sssd` won't start | `sssd.conf` perms not `0600` / wrong owner | `chmod 600 /etc/sssd/sssd.conf` (the helper does this) |
| `su - alice` "succeeds" with any password | You're root — root's `su` skips the password | Test as the unprivileged `tester` user |
| Config change to `sssd.conf` has no effect | `sssd` is serving stale cache | `sss_cache -E && pkill -x sssd && sssd` |
| User unresolvable / login fails after DC outage | `sssd` stuck offline or negative-cached | Confirm `dc1` is up, then `sss_cache -E` + restart `sssd` |

---

## What's Next

- **Lab 05 (DNS Deep Dive)** — the SRV-based discovery that made this join possible gets layered into a larger DNS hierarchy (conditional forwarding, split-horizon).
- **Lab 07 (File Shares)** — `sec=krb5` mounts use the very machine keytab and AD group membership you set up here for authorization.
- **Lab 08 (Group Policy & Config Mgmt)** — the computer objects in the Workstations OU become targets for enforced configuration across the fleet.
- **Lab 14 (SIEM)** — domain logon events from these members become one of the most valuable security log sources you collect.
