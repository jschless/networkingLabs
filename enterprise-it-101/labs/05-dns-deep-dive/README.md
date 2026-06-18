# Lab 05 — DNS Deep Dive

In Lab 01 the AD domain controller served DNS for `lab.corp`. Real enterprises
don't stop there: they run a dedicated resolver that recurses to the internet,
**conditionally forwards** the AD domain back to the DC, and serves **different
answers to internal vs. external clients** (split-horizon). In this lab you turn
a bare BIND9 server into exactly that resolver, then point your workstation at
it so a single server answers every kind of query.

## Topology

```
┌────────────────────────────────────────────────────────────────────────┐
│                      lab-corp  10.100.0.0/16                           │
│                                                                        │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐           │
│   │     dc1      │◀────│     dns1     │     │   admin-ws   │           │
│   │  Samba AD    │ fwd │   BIND9      │◀────│  internal    │           │
│   │  DNS (auth   │     │  resolver +  │     │  client      │           │
│   │  for         │     │  forwarder + │     │ 10.100.10.10 │           │
│   │  lab.corp)   │     │  split-horiz │     └──────────────┘           │
│   │ 10.100.1.10  │     │ 10.100.1.40  │     ┌──────────────┐           │
│   └──────────────┘     │      │       │◀────│  ext-client  │           │
│                        │      ▼       │     │  "outside"   │           │
│                   recursion to internet     │ 10.100.20.50 │           │
│                        (forwarders)         └──────────────┘           │
└────────────────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `dc1` | `samba-ad:local` | `10.100.1.10` | AD DC — authoritative for `lab.corp` (foundation) |
| `dns1` | `bind9:local` (custom) | `10.100.1.40` | BIND9 recursive resolver + conditional forwarder + split-horizon |
| `admin-ws` | `workstation:local` | `10.100.10.10` | **Internal** client (sees internal answers) |
| `ext-client` | `workstation:local` | `10.100.20.50` | **External** client — outside the internal view, sees external answers |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective**
and **hints** — your job is to figure out the config. Then:

- **Predict before you run.** Each task asks you to commit to an answer first.
  Guessing wrong and finding out why is how the knowledge sticks.
- **Reveal the solution only after you've tried.** Config is hidden behind
  `Solution` toggles. Reach for `man named.conf`, `named-checkconf`, and
  `dig` first.
- **Observe, don't just verify.** The `Check your work` toggles tell you what to
  look for *and why it matters* — read them even when your config loaded.

You will **edit BIND config files in place** on `dns1` (with `vim`) and apply
changes with `rndc reconfig`. That edit-then-reload loop *is* the lab — DNS
admins live in these files.

## Prerequisites

- **Labs 01–04 foundation.** This lab layers on `base/docker-compose.yml`.
- Build the custom images (if you haven't already):

```bash
cd enterprise-it-101
docker build -t samba-ad:local   images/samba-ad/
docker build -t workstation:local images/workstation/
docker build -t bind9:local       images/bind9/
```

## Deploy

```bash
cd enterprise-it-101
docker compose -f base/docker-compose.yml \
               -f labs/05-dns-deep-dive/docker-compose.override.yml up -d
```

Give `dc1` ~20–30 s to auto-provision the domain on first boot
(`docker exec dc1 samba-tool user list` should show alice/bob/charlie).

## Destroy

```bash
docker compose -f base/docker-compose.yml \
               -f labs/05-dns-deep-dive/docker-compose.override.yml down -v
```

---

## What is pre-built

- `dc1` — the AD DC, authoritative for `lab.corp` (Lab 01 foundation, seeded).
- `dns1` — BIND9 running with a **bare, recursion-off** config. It listens on
  port 53 but resolves nothing for anyone yet.
- `admin-ws` (internal) and `ext-client` (external) clients, both reachable via
  `docker exec`.

## What you configure

Everything on `dns1`. You'll enable recursion (safely), forward the AD domain
back to `dc1`, build split-horizon views, add a reverse zone, then repoint your
workstation's resolver at `dns1`. The config files live in `/etc/bind/` on
`dns1`:

| File | Holds |
|------|-------|
| `/etc/bind/named.conf.options` | global options + the `internal-clients` ACL |
| `/etc/bind/named.conf.local` | your zones and views |
| `/etc/bind/db.*` | zone data files you create |

After any edit: `named-checkconf` (validate) then `rndc reconfig` (apply).

---

## Task 1 — Turn dns1 into a recursive resolver (without becoming an open resolver)

**Objective:** Make `dns1` recurse to the internet **for internal clients only**.
A query for `google.com` from `admin-ws` should succeed; the same query from
`ext-client` (outside band `10.100.20.0/24`) should be refused.

??? question "Predict first"
    If you just set `recursion yes;` with no restriction, `dns1` will recurse
    for *anyone who can reach it*. Why is a wide-open recursive resolver
    dangerous on a network an attacker can reach — what attack does it enable?
    (Hint: think about a forged source IP and a small query that returns a big
    answer.)

??? note "Hints"
    - The two knobs in `options {}` are `recursion yes;` and `forwarders { … };`
      (where to send queries you can't answer yourself — e.g. `8.8.8.8`).
    - Define an `acl "internal-clients" { … };` listing the lab's internal
      subnets, then gate recursion. The gate is `allow-recursion { … };`.
    - Edit `/etc/bind/named.conf.options`. Validate with `named-checkconf`,
      apply with `rndc reconfig`.

??? note "Solution"
    Edit `/etc/bind/named.conf.options` on `dns1`:
    ```conf
    acl internal-clients {
        10.100.1.0/24;
        10.100.2.0/24;
        10.100.3.0/24;
        10.100.10.0/24;
        localhost;
    };

    options {
        directory "/var/cache/bind";
        listen-on    { any; };
        listen-on-v6 { none; };

        recursion yes;
        allow-recursion { internal-clients; };

        forwarders { 8.8.8.8; 1.1.1.1; };

        dnssec-validation auto;
    };
    ```
    Apply:
    ```bash
    docker exec dns1 named-checkconf      # must be silent / exit 0
    docker exec dns1 rndc reconfig
    ```
    Test from each client:
    ```bash
    docker exec admin-ws  dig @10.100.1.40 google.com A +short   # internal → works
    docker exec ext-client dig @10.100.1.40 google.com A         # external → refused
    ```

??? success "Check your work"
    - From **admin-ws** you get real A records (e.g. `142.251.x.x`). Recursion
      works for trusted clients.
    - From **ext-client** the header reads `status: REFUSED` with
      `;; WARNING: recursion requested but not available`. That client is in
      `10.100.20.0/24`, which is **not** in `internal-clients`, so `dns1`
      refuses to recurse for it.

    The danger you predicted is a **DNS amplification DDoS**: an attacker spoofs
    a victim's source IP, sends `dns1` a tiny query whose answer is large, and
    `dns1` blasts the big reply at the victim. `allow-recursion` (or, later,
    views) is what stops your resolver from being conscripted into that attack.

    > Needs internet: the `google.com` test only works if the host running
    > Docker can reach the internet. The `ext-client` REFUSED result does not.

---

## Task 2 — Conditionally forward lab.corp back to the DC

**Objective:** Make `dns1` answer `lab.corp` queries by **forwarding them to the
AD DNS on `dc1`** — so a client pointed at `dns1` can resolve both
`google.com` *and* `dc1.lab.corp`.

??? question "Predict first"
    You add a `type forward` zone for `lab.corp` pointing at `10.100.1.10`. You
    then run `dig @10.100.1.40 dc1.lab.corp A`. The record exists on `dc1`
    (you can prove it: `dig @10.100.1.10 dc1.lab.corp A +short` → `10.100.1.10`).
    Will the forwarded query **succeed**, or come back `SERVFAIL`? Commit to one.

??? note "Hints"
    - A conditional forwarder is a zone whose `type` is `forward`:
      ```conf
      zone "lab.corp" {
          type forward;
          forward only;
          forwarders { 10.100.1.10; };
      };
      ```
      Put it in `/etc/bind/named.conf.local`.
    - If your first attempt comes back `SERVFAIL`, read `docker logs dns1` —
      the reason is printed there, and it is **not** "can't reach dc1".
    - The fix lives back in `options {}`. Think about what `dns1` is trying to do
      to an answer from an **unsigned internal zone**.

??? note "Solution"
    Add the forward zone to `/etc/bind/named.conf.local`:
    ```conf
    zone "lab.corp" {
        type forward;
        forward only;
        forwarders { 10.100.1.10; };
    };
    ```
    Apply and test — you'll hit `SERVFAIL`:
    ```bash
    docker exec dns1 rndc reconfig
    docker exec admin-ws dig @10.100.1.40 dc1.lab.corp A +short   # → empty (SERVFAIL)
    docker logs dns1 | grep -i "trust chain" | tail -2
    # → "broken trust chain resolving 'dc1.lab.corp/A/IN': 10.100.1.10#53"
    ```
    The fix: tell BIND **not** to DNSSEC-validate the internal zone. Add to
    `options {}` in `named.conf.options`:
    ```conf
        dnssec-validation auto;
        validate-except { "lab.corp"; };
    ```
    Re-apply and retest:
    ```bash
    docker exec dns1 rndc reconfig
    docker exec admin-ws dig @10.100.1.40 dc1.lab.corp A +short            # → 10.100.1.10
    docker exec admin-ws dig @10.100.1.40 _ldap._tcp.lab.corp SRV +short   # → 0 100 389 dc1.lab.corp.
    ```

??? success "Check your work"
    First attempt: **`SERVFAIL`**, and `docker logs dns1` says
    **`broken trust chain resolving 'dc1.lab.corp/A/IN'`**. This is the gotcha:
    `dns1` runs `dnssec-validation auto`, so it tries to validate every answer
    against the DNSSEC chain of trust. The public root is signed — but your
    internal `lab.corp` zone on Samba is **unsigned**. With no signed delegation
    from the root down to `lab.corp`, validation can't build a chain and BIND
    refuses the answer as potentially tampered: `SERVFAIL`.

    `validate-except { "lab.corp"; }` tells BIND "this is a trusted internal
    domain — don't expect it to be signed." After that, `dc1.lab.corp` resolves
    and the `_ldap._tcp` / `_kerberos._tcp` SRV records — the ones a domain join
    depends on — flow through `dns1` to the DC. This SERVFAIL-on-internal-zone is
    one of the most common real-world BIND-in-front-of-AD mistakes.

---

## Task 3 — Build the internal view (split-horizon, part 1)

**Objective:** Add an internal DNS zone `apps.lab.corp` so that
`portal.apps.lab.corp` resolves to the **internal** app IP `10.100.2.50` — but
only for internal clients. To do per-client answers, you must restructure
`dns1` into **views**.

??? question "Predict first"
    BIND has one hard rule about views: *if any zone is inside a view, then
    **every** zone must be inside a view.* Given that, when you wrap your zones
    in a `view "internal" { … }` block, what has to happen to the `lab.corp`
    forward zone you wrote in Task 2? Can it stay at the top level?

??? note "Hints"
    - A view is `view "<name>" { match-clients { … }; <zones…> };`. Clients are
      matched **top-down, first match wins**.
    - The internal view's `match-clients` is your `internal-clients` ACL.
    - **Move** the `lab.corp` forward zone *inside* the internal view — top-level
      zones and views can't coexist.
    - Create a master zone `apps.lab.corp` pointing at a file you write, e.g.
      `/etc/bind/db.apps.internal` with one record: `portal A 10.100.2.50`.
    - A minimal zone file needs `$TTL`, an `SOA`, an `NS`, then your records.

??? note "Solution"
    Create `/etc/bind/db.apps.internal` on `dns1`:
    ```text
    $TTL 300
    @   IN  SOA dns1.lab.corp. hostmaster.lab.corp. ( 1 3600 600 86400 300 )
    @   IN  NS  dns1.lab.corp.
    portal  IN  A   10.100.2.50
    ```
    Rewrite `/etc/bind/named.conf.local` to wrap everything in a view:
    ```conf
    view "internal" {
        match-clients { internal-clients; };

        zone "lab.corp" {
            type forward;
            forward only;
            forwarders { 10.100.1.10; };
        };

        zone "apps.lab.corp" {
            type master;
            file "/etc/bind/db.apps.internal";
        };
    };
    ```
    Apply and test:
    ```bash
    docker exec dns1 named-checkconf
    docker exec dns1 rndc reconfig
    docker exec admin-ws dig @10.100.1.40 portal.apps.lab.corp A +short   # → 10.100.2.50
    ```

??? success "Check your work"
    `portal.apps.lab.corp` → **`10.100.2.50`** (TTL 300). The forward zone and
    recursion still work from `admin-ws`, because `admin-ws` matches the
    internal view. The answer to the prediction: the `lab.corp` forward zone
    **could not** stay at the top level — the moment a view exists, BIND requires
    *all* zones to live in views, or it won't start. You just learned why a
    seemingly small "add split-horizon" change forces a whole-config refactor.

---

## Task 4 — Add the external view and watch the same name return two answers

**Objective (make the invisible visible):** Add a second view that serves
`portal.apps.lab.corp` → **`203.0.113.50`** (a simulated public IP) to clients
*outside* the internal band. Then prove that one query name yields two different
answers depending on **who asks**.

??? question "Predict first"
    `ext-client` (`10.100.20.50`) is **not** in `internal-clients`. After you add
    a `view "external" { match-clients { any; }; … }` block *below* the internal
    view, which view will `ext-client` match — and which will `admin-ws` match?
    Why does ordering matter here?

??? note "Hints"
    - Views match top-down, first match wins. The internal view (specific ACL)
      must come **first**; the external view (`match-clients { any; }`) is the
      catch-all **last**.
    - The external view should **not** recurse and should **not** forward
      `lab.corp` (outsiders have no business resolving your internal domain).
      Set `recursion no;` in it.
    - Create `/etc/bind/db.apps.external` — same zone, `portal A 203.0.113.50`.
    - When you add a view with `recursion no;`, `named-checkconf` will *warn*
      that the `allow-recursion` you set in `options {}` (Task 1) is now
      redundant there. Once you have views, `match-clients` already decides who
      can recurse — so **remove `allow-recursion` from `options {}`** to clear
      the warning.

??? note "Solution"
    Create `/etc/bind/db.apps.external`:
    ```text
    $TTL 300
    @   IN  SOA dns1.lab.corp. hostmaster.lab.corp. ( 1 3600 600 86400 300 )
    @   IN  NS  dns1.lab.corp.
    portal  IN  A   203.0.113.50
    ```
    First, drop the now-redundant `allow-recursion` line from `options {}` in
    `named.conf.options` (the internal view's `match-clients` gates recursion
    now). Then append the external view to `named.conf.local` (after the
    internal view):
    ```conf
    view "external" {
        match-clients { any; };
        recursion no;

        zone "apps.lab.corp" {
            type master;
            file "/etc/bind/db.apps.external";
        };
    };
    ```
    Apply, then ask the **same question from both clients**:
    ```bash
    docker exec dns1 rndc reconfig
    docker exec admin-ws  dig @10.100.1.40 portal.apps.lab.corp A +short   # → 10.100.2.50
    docker exec ext-client dig @10.100.1.40 portal.apps.lab.corp A +short  # → 203.0.113.50
    ```

??? success "Check your work"
    Same name, **two answers**: `admin-ws` → `10.100.2.50`, `ext-client` →
    `203.0.113.50`. That is split-horizon DNS, and it's how enterprises publish
    one hostname that points employees at the internal server and the public at
    the DMZ/load-balancer. The mechanism is entirely `match-clients` + view
    order: `admin-ws` matches the specific `internal-clients` ACL first;
    `ext-client` falls through to the `any` catch-all.

    Now confirm the external view is properly *isolated*:
    ```bash
    docker exec ext-client dig @10.100.1.40 dc1.lab.corp A | grep status:
    # → status: REFUSED  (external view has no lab.corp forward, no recursion)
    ```
    An outsider pointed at your resolver can see only what the external view
    publishes — not your AD records, not the internet. The view boundary is a
    security boundary.

---

## Task 5 — Add a reverse zone (PTR records)

**Objective:** Create a reverse zone for `10.100.1.0/24` so that
`dig -x 10.100.1.10` returns `dc1.lab.corp` and `dig -x 10.100.1.40` returns
`dns1.lab.corp`.

??? question "Predict first"
    Forward DNS maps name → IP. Reverse DNS maps IP → name, and it lives under a
    specially-named zone. For the subnet `10.100.1.0/24`, what is the **name of
    the reverse zone**, and in what order do the octets appear? (Hint: it ends in
    `.in-addr.arpa` and the address is reversed.)

??? note "Hints"
    - The zone for `10.100.1.0/24` is `1.100.10.in-addr.arpa`.
    - PTR record names are just the **host octet**: `10` and `40`.
    - It's an internal-only concern — put the zone inside the **internal** view.
    - PTR data is a fully-qualified name ending in a dot:
      `10  IN  PTR  dc1.lab.corp.`

??? note "Solution"
    Create `/etc/bind/db.10.100.1`:
    ```text
    $TTL 300
    @   IN  SOA dns1.lab.corp. hostmaster.lab.corp. ( 1 3600 600 86400 300 )
    @   IN  NS  dns1.lab.corp.
    10  IN  PTR dc1.lab.corp.
    40  IN  PTR dns1.lab.corp.
    ```
    Add the zone to the **internal** view in `named.conf.local`:
    ```conf
        zone "1.100.10.in-addr.arpa" {
            type master;
            file "/etc/bind/db.10.100.1";
        };
    ```
    Apply and test:
    ```bash
    docker exec dns1 rndc reconfig
    docker exec admin-ws dig @10.100.1.40 -x 10.100.1.10 +short   # → dc1.lab.corp.
    docker exec admin-ws dig @10.100.1.40 -x 10.100.1.40 +short   # → dns1.lab.corp.
    ```

??? success "Check your work"
    `-x 10.100.1.10` → `dc1.lab.corp.` and `-x 10.100.1.40` → `dns1.lab.corp.`
    The zone name reverses the network octets and appends `.in-addr.arpa`
    because reverse DNS is itself a tree, delegated the same way forward DNS is
    (the `in-addr.arpa` hierarchy mirrors IP allocation). Reverse records aren't
    cosmetic: mail servers reject senders with no PTR, and every log line that
    shows a hostname instead of a bare IP went through a reverse lookup.

---

## Task 6 — Make dns1 your one resolver, and watch it recurse

**Objective:** Repoint `admin-ws` at `dns1` as its primary resolver, confirm a
single server now answers *both* internet and `lab.corp` names, then use
`dig +trace` to watch a recursive resolution walk the DNS hierarchy.

??? question "Predict first"
    Right now `admin-ws` resolves via the AD DNS (`10.100.1.10`), which knows
    `lab.corp` but forwards everything else. After you point it at `dns1`
    instead, will it still resolve `dc1.lab.corp`? Will it now also resolve
    `google.com` *through the same server*? Why is "one resolver for everything"
    the normal enterprise design?

??? note "Hints"
    - The resolver list is `/etc/resolv.conf`. Set `nameserver 10.100.1.40`.
      (This is ephemeral — Docker rewrites it on container restart. That's fine.)
    - Verify with `getent hosts <name>` (uses the system resolver, not a
      hard-coded `@server`).
    - `dig +trace <name>` asks the root servers, then follows referrals down —
      it shows you the recursion `dns1` does on your behalf.

??? note "Solution"
    ```bash
    docker exec admin-ws bash -c 'printf "nameserver 10.100.1.40\nsearch lab.corp\n" > /etc/resolv.conf'

    docker exec admin-ws getent hosts dc1.lab.corp    # internal name → 10.100.1.10
    docker exec admin-ws getent hosts google.com      # internet name → public IP

    docker exec admin-ws dig @10.100.1.40 +trace example.com A
    ```

??? success "Check your work"
    Both `getent` lookups succeed through the **single** server `10.100.1.40`:
    the internal name comes back via the conditional forward to `dc1`, the
    internet name via recursion. That's the enterprise pattern — clients know
    about *one* resolver, and that resolver decides per-query whether to forward
    internally or recurse externally. Clients never need to know the difference.

    `dig +trace` prints the root nameservers (`a.root-servers.net.` …), then the
    TLD servers, then the authoritative servers — the exact chain `dns1` walks
    when it can't answer from cache or a forward zone. This is the single most
    useful command for "why won't this name resolve?" because it shows you
    *which level* of the hierarchy breaks.

---

## Task 7 — Break it: delete the conditional forward and diagnose

**Objective (required):** Remove the `lab.corp` forward zone, flush the cache,
and watch a **Kerberos-looking failure** appear on a client that uses `dns1`.
Diagnose it from the symptom, then repair. Every earlier task assumed this one
zone — now feel its absence.

??? question "Predict first"
    `dns1` still has `recursion yes` and internet forwarders. If you delete the
    `lab.corp` conditional-forward zone, where will `dns1` send a query for
    `dc1.lab.corp`? What will the **public internet** say about a name in
    `lab.corp`? And what error will that produce when a client tries to
    `kinit alice@LAB.CORP`?

**Break it** — edit `/etc/bind/named.conf.local` on `dns1` and delete (or
comment out) the `lab.corp` forward zone inside the internal view, then:
```bash
docker exec dns1 rndc reconfig
docker exec dns1 rndc flush          # crucial — clear cached lab.corp answers
```

**Now diagnose from a client** that resolves via `dns1` (Task 6 left `admin-ws`
pointed there):
```bash
docker exec admin-ws kdestroy 2>/dev/null
docker exec admin-ws getent hosts dc1.lab.corp        # observe
docker exec admin-ws dig @10.100.1.40 dc1.lab.corp A | grep status:
docker exec admin-ws bash -c 'kinit alice@LAB.CORP <<< "P@ssw0rd1"'   # observe the error
```

??? note "Diagnosis hints (try before revealing)"
    - Did `getent` succeed or fail? Did `dig` say `NOERROR`, `SERVFAIL`, or
      `NXDOMAIN`? **`NXDOMAIN` is the tell** — something *authoritatively*
      answered "this name does not exist."
    - Who answered authoritatively? You deleted the forward to `dc1`, so `dns1`
      *recursed to the public internet* for `dc1.lab.corp`. What does the public
      internet think of `lab.corp`?
    - Why did `rndc flush` matter? What would you have seen without it, and why
      would that have hidden the bug?

??? success "What you should observe"
    - `dig @10.100.1.40 dc1.lab.corp A` → **`status: NXDOMAIN`**. With the
      conditional forward gone, `dns1` recursed to the public root, which has no
      `lab.corp` TLD, so the internet authoritatively answered "no such name."
    - `getent hosts dc1.lab.corp` → **fails (exit 2)**.
    - `kinit alice@LAB.CORP` → **`kinit: Cannot contact any KDC for realm
      'LAB.CORP'`**. Read that error: it blames *Kerberos*, but Kerberos is
      fine — the client simply can't **resolve the KDC's name**, because the
      conditional forward that turns `lab.corp` queries toward `dc1` is gone and
      the query leaked to the public internet. Symptom (Kerberos) ≠ root cause
      (DNS). This mismatch is why DNS outages get misdiagnosed as auth outages.
    - **`rndc flush` mattered** because `dns1` had `dc1.lab.corp` cached from
      earlier tasks (TTL up to 900 s). Without flushing, the stale cached record
      would keep answering and hide the break — exactly the kind of "but it
      worked a minute ago" that makes caching bugs maddening.

**Repair it** — restore the forward zone, reload, and flush:
```bash
# put the lab.corp forward zone back inside view "internal", then:
docker exec dns1 rndc reconfig
docker exec dns1 rndc flush
docker exec admin-ws bash -c 'kdestroy 2>/dev/null; kinit alice@LAB.CORP <<< "P@ssw0rd1" && klist | grep krbtgt'
```
A TGT for `krbtgt/LAB.CORP@LAB.CORP` in `klist` confirms the repair.

---

## Verification Checklist

Run these to confirm `dns1` is a complete enterprise resolver before moving on:

```bash
# 1) Recursion for internal clients, refused for external
docker exec admin-ws  dig @10.100.1.40 google.com A +short          # answers (needs internet)
docker exec ext-client dig @10.100.1.40 google.com A | grep status: # REFUSED

# 2) Conditional forward to AD (the records a domain join needs)
docker exec admin-ws dig @10.100.1.40 dc1.lab.corp A +short            # 10.100.1.10
docker exec admin-ws dig @10.100.1.40 _ldap._tcp.lab.corp SRV +short   # 0 100 389 dc1.lab.corp.

# 3) Split-horizon: same name, two answers
docker exec admin-ws  dig @10.100.1.40 portal.apps.lab.corp A +short   # 10.100.2.50
docker exec ext-client dig @10.100.1.40 portal.apps.lab.corp A +short  # 203.0.113.50

# 4) Reverse DNS
docker exec admin-ws dig @10.100.1.40 -x 10.100.1.10 +short            # dc1.lab.corp.
docker exec admin-ws dig @10.100.1.40 -x 10.100.1.40 +short            # dns1.lab.corp.

# 5) Config sanity
docker exec dns1 named-checkconf && echo "config OK"
```

---

## Challenge Questions

No solutions provided — these test whether you can reason about the system.

1. **Forward vs. stub vs. recursion.** You configured `lab.corp` as a `type
   forward` zone. BIND also has `type stub` and, of course, full recursion. For
   resolving an *internal AD domain you don't host*, why is conditional
   forwarding the right tool — and what specifically goes wrong (you saw it in
   Task 7) if you rely on plain recursion for an internal-only domain instead?

2. **View ordering bug.** A colleague puts the `external` view (`match-clients {
   any; }`) **first** and the `internal` view second. The config loads fine and
   `ext-client` works. What breaks, for whom, and why — and what's the single
   rule that prevents this class of bug?

3. **The DNSSEC SERVFAIL, generalized.** You fixed `lab.corp` with
   `validate-except`. Your company acquires another firm and you add a
   conditional forward for *their* internal domain `acme.internal` — and it
   `SERVFAIL`s. Walk through the diagnosis and the fix. What would you check
   first to confirm it's the same root cause?

4. **Add a second resolver.** You deploy `dns2` for redundancy. What must change
   on the **clients**, and what must you keep **in sync** between `dns1` and
   `dns2` for split-horizon to stay correct? Is there any state that *can't*
   simply be copied?

5. **Design extension.** Lab 06 adds DHCP. DHCP can hand clients a DNS server
   option. Given what you built here, **which IP** should DHCP advertise as the
   resolver — `dns1` (`10.100.1.40`) or the AD DNS (`10.100.1.10`) — and what
   capability would clients lose if you chose the other one?

---

## Key Concepts

**Layered enterprise DNS.** AD DNS (`dc1`) is authoritative for the domain;
BIND (`dns1`) is the recursive resolver clients actually point at. `dns1`
forwards domain queries back to `dc1` and recurses everything else. Clients know
about one resolver; it routes per-query.

| Mechanism | Config | Purpose |
|-----------|--------|---------|
| Recursion + `allow-recursion` | `options {}` | Resolve the internet for *trusted* clients only (not an open resolver) |
| Conditional forward | `zone "lab.corp" { type forward; }` | Send the AD domain to the DC instead of the public internet |
| `validate-except` | `options {}` | Don't DNSSEC-validate unsigned *internal* zones (avoids SERVFAIL) |
| Views + `match-clients` | `view "…" { … }` | Different answers per client = split-horizon; also a security boundary |
| Reverse zone | `zone "1.100.10.in-addr.arpa"` | IP → name (PTR); required by mail and sane logging |

**Split-horizon = `match-clients`, first match wins.** Order views specific →
catch-all. The view boundary keeps outsiders from seeing internal records.

**`dig` is the debugger.** `@server` to target a resolver; `+short` for terse
answers; `-x` for reverse; `+trace` to watch recursion walk the hierarchy;
read the `status:` line (`NOERROR` / `SERVFAIL` / `NXDOMAIN`) — each points at a
different layer.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `dig` internal name → `SERVFAIL`, log says "broken trust chain" | DNSSEC validating an unsigned internal zone | `validate-except { "lab.corp"; };` |
| `dig` → `REFUSED` from a client | Client not in `allow-recursion` / matched the external view | Check the ACL and view `match-clients` |
| `named-checkconf`: "all zones must be in views" | A zone left at top level after adding a view | Move every zone inside a view |
| Edited a zone file but answer is stale | `rndc reconfig` reloads config, not changed zone *data* | `rndc reload <zone> in <view>`, bump the SOA serial |
| Internal name → `NXDOMAIN` after a change | Conditional forward missing; query leaked to public internet | Restore the `lab.corp` forward zone; `rndc flush` |
| "But it worked a second ago" | Cached answer surviving a config change | `rndc flush` and retest |
| External view "leaks" internet | External view has `recursion yes` or forwarders | Set `recursion no;` and no forwarders in it |
| New zone added but `rndc zonestatus` says "not found" / query still goes to root | `rndc reconfig` sometimes doesn't pick up new zones or views reliably | `docker restart dns1` — since `named` is PID 1, this does a clean restart and forces a full re-read of all config |
| `dc1` samba exits immediately (status 1), port 53 closed, `docker logs dc1` shows crash loop | `dc1-data` volume persists the AD database across a container recreation, but `/etc/samba/smb.conf` and `/etc/krb5.conf` live in the container layer and get reset — Samba sees `server role = standalone server` and bails | Redeploy with `-v` to wipe the volume and let auto-provision regenerate everything: `docker compose … down -v && docker compose … up -d` |

---

## What's Next

- **Lab 06 (DHCP & Dynamic DNS)** — clients will be handed `dns1` as their
  resolver automatically via DHCP option 6, and DHCP will register their names
  into AD DNS dynamically (the reverse of what you forwarded here).
- **Lab 09 (Email Gateway)** — you'll add the `MX` record and rely on the PTR
  records from Task 5 (mail servers reject senders without reverse DNS).
- **Every later lab** points clients at a resolver. The split-horizon and
  conditional-forward patterns here are how all of them reach both internal
  services and the internet through one server.
