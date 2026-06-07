# Lab 11 — Web Proxy & Filtering

Put a **Squid** forward proxy in front of the web and make it authenticate every
user against Active Directory — *transparently*, with **Kerberos Negotiate** (no
password prompt) — then enforce different web access for different AD groups. This
is how enterprises log "who went where" and apply per-department web policy.

You'll turn on Kerberos auth so the proxy learns each user's identity from a
service ticket, add AD group-based ACLs so **engineering** browses freely while
**finance** is blocked from one site, watch the access log attribute every request
to a named user, and break the proxy's service key to see authentication collapse
with a misleading "auth required" symptom.

## Topology

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         lab-corp  10.100.0.0/16                            │
│                                                                            │
│  ┌────────────┐         ┌──────────────┐        ┌────────────────────────┐ │
│  │    dc1     │  krb/   │    proxy1    │  HTTP  │   webserver1 (allowed) │ │
│  │ Samba AD   │◄──ldap─►│ Squid + krb5 │◄──────►│   10.100.2.41          │ │
│  │ 10.100.1.10│         │ 10.100.2.40  │        ├────────────────────────┤ │
│  └────────────┘         │   :3128      │  HTTP  │   webserver2 (blocked  │ │
│        ▲                └──────┬───────┘◄──────►│   for finance)         │ │
│        │ kinit (TGT)          │ proxy           │   10.100.2.42          │ │
│  ┌─────┴───────┐              │ auth            └────────────────────────┘ │
│  │     ws1     │──────────────┘  (Negotiate / SPNEGO)                      │
│  │ 10.100.10.11│   curl --proxy-negotiate                                  │
│  └─────────────┘                                                           │
└────────────────────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `dc1` | `samba-ad:local` | `10.100.1.10` | AD DC (Kerberos + LDAP) |
| `proxy1` | `squid-ad:local` (custom) | `10.100.2.40` (`:3128`) | Squid proxy, domain-joined, Kerberos auth |
| `webserver1` | `nginx:alpine` | `10.100.2.41` | "Allowed" origin site |
| `webserver2` | `nginx:alpine` | `10.100.2.42` | "Restricted" origin site |
| `ws1` | `workstation:local` | `10.100.10.11` | Authenticating client (alice / bob) |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective**
and **hints** — your job is to figure out the config. Then:

- **Predict before you run.** Commit to an answer first; being wrong and seeing why
  is the point.
- **Reveal the solution only after you've tried.** `configs/squid.conf` is the file
  you edit; full answers are behind `Solution` toggles.
- **Observe, don't just verify.** The `Check your work` toggles explain the
  mechanism, not just the result.

You edit `configs/squid.conf` on the host; it's bind-mounted into proxy1. After
each edit, reload with `docker exec proxy1 squid -k reconfigure`.

## Prerequisites

- Lab 01 concepts (Kerberos tickets, AD groups). The foundation (`dc1`, the
  `engineering`/`finance` groups, alice/bob) is auto-provisioned here.
- Build the custom image (first deploy does this automatically):
  ```bash
  docker build -t squid-ad:local images/squid-ad/
  ```

## Deploy

```bash
cd enterprise-it-101
docker compose -f base/docker-compose.yml \
               -f labs/11-web-proxy/docker-compose.override.yml up -d --build
```

`proxy1` joins the domain and mints its keytab on first boot — watch it finish:

```bash
docker logs proxy1 2>&1 | grep -A12 "keytab principals"
```

## Destroy

```bash
docker compose -f base/docker-compose.yml \
               -f labs/11-web-proxy/docker-compose.override.yml down -v
```

---

## What is pre-built

- `proxy1` is **joined to lab.corp** and has `/etc/squid/PROXY.keytab` containing
  the `HTTP/proxy1.lab.corp@LAB.CORP` service key (for validating client tickets)
  and the machine account key (for the group helper's LDAP bind). `KRB5_KTNAME`
  already points Squid's helpers at it.
- `webserver1` / `webserver2` serve distinct pages; proxy1 resolves them.
- `ws1` is a client with `kinit`, `curl` (built with SPNEGO), and `proxy1.lab.corp`
  resolvable.
- A starter `squid.conf` that currently **denies everything** — you make it work.

## What you configure

The Squid policy: Kerberos authentication and AD group-based access rules. That's
the whole lab.

---

## Task 1 — Survey the starting line

**Objective:** Confirm what the join handed you, and confirm the proxy currently
blocks all traffic (so you know your later changes are what open it).

??? question "Predict first"
    The join script ran `net ads join` then `net ads keytab add HTTP/proxy1.lab.corp`.
    Which Kerberos principal must be in `/etc/squid/PROXY.keytab` for Squid to
    *validate* a ticket a browser presents for the proxy? (Hint: it's the proxy's
    own service identity, not the user's.)

??? note "Hints"
    - `klist -k <keytab>` lists a keytab's principals.
    - Try the proxy with no config help: `curl -x http://proxy1.lab.corp:3128 http://webserver1.lab.corp/`.

??? note "Solution"
    ```bash
    # On proxy1: what service identities did the join give us?
    docker exec proxy1 klist -k /etc/squid/PROXY.keytab | grep -iE 'HTTP|PROXY1\$'

    # From ws1: the proxy denies everything right now
    docker exec ws1 curl -s -o /dev/null -w "%{http_code}\n" \
      -x http://proxy1.lab.corp:3128 http://webserver1.lab.corp/
    ```

??? success "Check your work"
    The keytab lists `HTTP/proxy1.lab.corp@LAB.CORP` (the **acceptor** identity —
    Squid uses its key to decrypt and validate the service ticket a client presents)
    and `PROXY1$@LAB.CORP` (the **machine account**, used later by the group helper
    to bind to LDAP). The bare proxy request returns **403** — the starter config is
    `http_access deny all`. Everything you make work from here is your doing.

---

## Task 2 — Turn on Kerberos Negotiate authentication

**Objective:** Make the proxy require Kerberos auth, then prove a domain user can
browse through it **without ever typing a password at the proxy**.

??? question "Predict first"
    With Kerberos Negotiate, the client proves identity to the proxy with a *service
    ticket*. When you `curl` through the proxy as alice, will alice's **password**
    travel to `proxy1`? What new ticket will appear in her cache afterward, beyond
    the TGT from `kinit`?

??? note "Hints"
    - In `configs/squid.conf`, add an `auth_param negotiate` block: the helper is
      `/usr/lib/squid/negotiate_kerberos_auth`, the keytab is `-k /etc/squid/PROXY.keytab`,
      and the service principal is `-s HTTP/proxy1.lab.corp@LAB.CORP`.
    - Require auth with `acl authenticated proxy_auth REQUIRED` and an
      `http_access allow authenticated` (remove the catch-all deny).
    - Reload: `docker exec proxy1 squid -k reconfigure`.
    - The client must ask for **proxy** auth, not origin auth: `curl --proxy-negotiate -U :`.

??? note "Solution"
    In `configs/squid.conf`:
    ```squid
    http_port 3128

    auth_param negotiate program /usr/lib/squid/negotiate_kerberos_auth -k /etc/squid/PROXY.keytab -s HTTP/proxy1.lab.corp@LAB.CORP
    auth_param negotiate children 10
    auth_param negotiate keep_alive on

    acl authenticated proxy_auth REQUIRED
    http_access deny !authenticated
    http_access allow authenticated
    http_access deny all

    cache deny all
    coredump_dir /var/spool/squid
    access_log /var/log/squid/access.log
    visible_hostname proxy1.lab.corp
    ```
    Reload and test from the client:
    ```bash
    docker exec proxy1 squid -k reconfigure
    docker exec -it ws1 bash
      kinit alice@LAB.CORP            # password: P@ssw0rd1
      curl -s -o /dev/null -w "%{http_code}\n" \
        --proxy-negotiate -U : -x http://proxy1.lab.corp:3128 http://webserver1.lab.corp/
      klist | grep HTTP/proxy1
    ```

??? success "Check your work"
    The request returns **200**, and `klist` now shows a second ticket:
    `HTTP/proxy1.lab.corp@LAB.CORP`. That's the proof of how Negotiate works — alice's
    client took her TGT, asked the KDC for a **service ticket** for the proxy, and
    handed *that* to Squid (SPNEGO). Her password never reached `proxy1`; Squid
    validated the ticket with its own keytab. `--proxy-negotiate` (not `--negotiate`)
    is what makes curl authenticate to the *proxy* rather than the origin server. In a
    real browser with the proxy configured, this is seamless — no password prompt at all.

---

## Task 3 — Enforce per-group web policy

**Objective:** Make **engineering** unrestricted but block **finance** from
`webserver2.lab.corp`, decided purely by AD group membership.

??? question "Predict first"
    `http_access` rules are evaluated **top to bottom, first match wins**. Given you
    want engineering to reach *everything* and finance to reach everything *except*
    webserver2, what must the order of `allow in_engineering` and
    `deny site_blocked` be? What happens if you put the deny first?

??? note "Hints"
    - The helper `/usr/lib/squid/ext_kerberos_ldap_group_acl -g <group>` takes the
      authenticated `%LOGIN` and returns OK if the user is in `<group>`.
    - Wire it with `external_acl_type ad_engineering ttl=300 %LOGIN /usr/lib/squid/ext_kerberos_ldap_group_acl -g engineering`,
      then `acl in_engineering external ad_engineering`.
    - `acl site_blocked dstdomain webserver2.lab.corp` matches the requested site.
    - Build the policy so engineering is allowed before the block applies to everyone else.

??? note "Solution"
    Replace the policy section of `configs/squid.conf` with:
    ```squid
    external_acl_type ad_engineering ttl=300 %LOGIN /usr/lib/squid/ext_kerberos_ldap_group_acl -g engineering

    acl authenticated proxy_auth REQUIRED
    acl in_engineering external ad_engineering
    acl site_blocked dstdomain webserver2.lab.corp

    http_access deny !authenticated
    http_access allow in_engineering
    http_access deny site_blocked
    http_access allow authenticated
    http_access deny all
    ```
    Reload and test both users:
    ```bash
    docker exec proxy1 squid -k reconfigure
    docker exec -it ws1 bash
      kinit alice@LAB.CORP   # engineering
      curl -s -o /dev/null -w "alice ws1 %{http_code}\n" --proxy-negotiate -U : -x http://proxy1.lab.corp:3128 http://webserver1.lab.corp/
      curl -s -o /dev/null -w "alice ws2 %{http_code}\n" --proxy-negotiate -U : -x http://proxy1.lab.corp:3128 http://webserver2.lab.corp/
      kinit bob@LAB.CORP     # finance
      curl -s -o /dev/null -w "bob   ws1 %{http_code}\n" --proxy-negotiate -U : -x http://proxy1.lab.corp:3128 http://webserver1.lab.corp/
      curl -s -o /dev/null -w "bob   ws2 %{http_code}\n" --proxy-negotiate -U : -x http://proxy1.lab.corp:3128 http://webserver2.lab.corp/
    ```

??? success "Check your work"
    | user | webserver1 | webserver2 |
    |------|-----------|-----------|
    | alice (engineering) | 200 | **200** |
    | bob (finance) | 200 | **403** |

    Engineering is waved through by `allow in_engineering` *before* the
    `deny site_blocked` rule is ever reached — so the block only bites non-engineering
    users. The group helper authenticated as the machine account, bound to the DC over
    GSSAPI, and looked up each user's `memberOf`. **Authorization rode entirely on AD
    group membership** — you didn't list a single username in the proxy. Reorder the two
    rules (deny first) and engineering would also be blocked from webserver2: in Squid,
    rule order *is* the policy.

---

## Task 4 — Make it visible: the access log and the wire

**Objective:** Confirm the proxy records exactly *who* did *what*, and confirm the
client only ever held tickets — never sent a password to the proxy.

??? note "Hints"
    - `tail /var/log/squid/access.log` on proxy1 — note the username and the
      `TCP_DENIED/403` vs `TCP_MISS/200` result codes.
    - On ws1, `klist` shows the ticket cache: a TGT plus the proxy service ticket.

??? note "Solution"
    ```bash
    docker exec proxy1 tail -6 /var/log/squid/access.log
    docker exec ws1 klist
    ```

??? success "Check your work"
    Each log line carries the **authenticated principal** (`alice@LAB.CORP`,
    `bob@LAB.CORP`) and the verdict — e.g. `TCP_MISS/200 ... webserver1.lab.corp alice@LAB.CORP`
    and `TCP_DENIED/403 ... webserver2.lab.corp bob@LAB.CORP`. *This* is the compliance
    payoff of a proxy: every request is attributable to a named user, with allow/deny
    recorded. On the client, `klist` shows only a `krbtgt/...` TGT and an
    `HTTP/proxy1.lab.corp` service ticket — never a password. The proxy enforced and
    logged identity it proved cryptographically, not credentials it stored.

---

## Task 5 — Break it: poison the proxy's service key

**Objective (required):** Make the proxy validate tickets against the *wrong*
service principal. Watch authentication collapse with a symptom that blames the
*client*, diagnose it from the proxy logs, and repair it.

??? question "Predict first"
    If Squid tries to accept tickets for `HTTP/wrong.lab.corp` — a principal whose
    key is **not** in its keytab — what will a client with a perfectly valid Kerberos
    ticket see? An error that says "the proxy is misconfigured", or one that looks
    like the *client* failed to authenticate?

**Break it** — in `configs/squid.conf`, change the auth helper's service principal:
```
-s HTTP/proxy1.lab.corp@LAB.CORP   →   -s HTTP/wrong.lab.corp@LAB.CORP
```
then `docker exec proxy1 squid -k reconfigure`. Now, as alice (with a valid TGT):
```bash
docker exec ws1 bash -c 'kinit alice@LAB.CORP <<<P@ssw0rd1 >/dev/null 2>&1
  curl -s -o /dev/null -w "%{http_code}\n" --proxy-negotiate -U : \
    -x http://proxy1.lab.corp:3128 http://webserver1.lab.corp/'
```

??? note "Diagnosis hints (try before revealing)"
    - What HTTP status comes back — does it look like *your* problem or the proxy's?
    - Look where the truth is: `docker exec proxy1 tail /var/log/squid/cache.log`.
      Grep for `gss` / `keytab` / `principal`.

??? success "What you should observe"
    alice — *with a valid ticket* — gets **407 Proxy Authentication Required**, exactly
    as if she'd never authenticated. But the cause is entirely server-side; the proxy's
    `cache.log` says it plainly:
    ```
    ERROR: Negotiate Authentication ... gss_acquire_cred() failed:
    ... No principal in keytab matches desired name
    ```
    Squid can't load a key for `HTTP/wrong.lab.corp`, so it can't accept *any* ticket and
    challenges every request anew. The symptom (407, "authenticate please") points at the
    client; the cause is the proxy's acceptor identity. This mismatch is why "users can't
    auth to the proxy" tickets so often waste time on the user's machine — **the log on the
    proxy is the source of truth.**

**Repair it:** restore `-s HTTP/proxy1.lab.corp@LAB.CORP`, `squid -k reconfigure`,
and confirm alice is back to **200**.

---

## Verification Checklist

```bash
# proxy1 is joined and has the HTTP service key
docker exec proxy1 klist -k /etc/squid/PROXY.keytab | grep HTTP/proxy1

# engineering vs finance policy (run from ws1, after kinit per user)
docker exec -it ws1 bash
  kinit alice@LAB.CORP
  curl -s -o /dev/null -w "alice->ws2 %{http_code}\n" --proxy-negotiate -U : -x http://proxy1.lab.corp:3128 http://webserver2.lab.corp/   # 200
  kinit bob@LAB.CORP
  curl -s -o /dev/null -w "bob->ws2   %{http_code}\n" --proxy-negotiate -U : -x http://proxy1.lab.corp:3128 http://webserver2.lab.corp/   # 403

# the log attributes requests to named users
docker exec proxy1 tail -4 /var/log/squid/access.log
```

---

## Challenge Questions

No answers provided.

1. **Bypass.** The proxy only filters traffic that *goes through it*. If bob set his
   shell's `http_proxy` aside and hit `webserver2` directly, he'd reach it. What does
   that tell you about where web filtering must actually be *enforced* in a real
   network, and what two controls would you add so users can't simply opt out?

2. **HTTPS blind spot.** Everything here was plain HTTP, so Squid could see the URL
   and the page. If `webserver2` were HTTPS, what could the proxy still see (and log)
   to make an allow/deny decision, and what would it *not* see? What is "SSL bump" and
   why is it organisationally controversial?

3. **Ticket lifetime.** alice's proxy service ticket has a finite lifetime. After it
   expires mid-session, what does her browser do to keep browsing — and why does she
   never notice? (Tie this back to the TGT from Task 2.)

4. **Group helper failure mode.** The `ext_kerberos_ldap_group_acl` helper binds to the
   DC to check membership. If the DC were unreachable, should the proxy *fail open*
   (allow) or *fail closed* (deny)? Argue it from a security standpoint, then from an
   availability standpoint — they conflict.

5. **Design extension.** You add a second proxy `proxy2` for load balancing. What must
   be true of *its* keytab and SPN for clients to authenticate to it, and what AD object
   changes when you register `HTTP/proxy2.lab.corp`?

---

## Key Concepts

**Kerberos Negotiate (SPNEGO) for proxies.** The client trades its TGT for a service
ticket for `HTTP/<proxy-fqdn>` and presents it; the proxy validates it with its keytab.
No password reaches the proxy, and there's no prompt — single sign-on for the web.

| Piece | Role |
|-------|------|
| `HTTP/proxy1.lab.corp` SPN + keytab | The proxy's **acceptor** identity; validates client tickets |
| Machine account (`PROXY1$`) key | Used by the group helper to **bind to LDAP** over GSSAPI |
| `negotiate_kerberos_auth` | Auth helper: ticket → authenticated username |
| `ext_kerberos_ldap_group_acl -g X` | External ACL: is this user in AD group X? |
| `http_access` order | First match wins — rule order *is* the policy |

**`--proxy-negotiate` vs `--negotiate`.** The former authenticates to the *proxy*, the
latter to the *origin server*. Using the wrong one yields an endless 407.

**The proxy is the audit point.** Every request is logged against a cryptographically
proven user identity with an allow/deny verdict — the foundation of web compliance and
forensics.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Every request → 407, even with a valid TGT | Wrong/missing `-s` SPN or unreadable keytab | Match `-s HTTP/proxy1.lab.corp@LAB.CORP`; check `cache.log` for `gss_acquire_cred` |
| 407 with `--negotiate` but works with `--proxy-negotiate` | Authenticating to origin, not proxy | Use `--proxy-negotiate -U :` |
| All users blocked from webserver2 (even engineering) | `deny site_blocked` placed before `allow in_engineering` | Reorder: allow engineering first |
| Group helper never returns OK; `cache.log` shows SASL "Local error" | Missing `SASL_NOCANON on` (reverse-DNS canonicalisation) | Pre-set in the image's `/etc/ldap/ldap.conf` — rejoin if you wiped it |
| `squid -k reconfigure` → "Bad PID file" | Squid was started as PID 1 | The join script runs Squid as a daemon + tails logs so reload works |
| `kinit` "Cannot find KDC" | DNS/realm misconfig on the client | `dig @10.100.1.10 _kerberos._tcp.lab.corp SRV` |

---

## What's Next

- **Lab 12 (RADIUS)** — authenticate *network* logins (switches, Wi-Fi, VPN) against
  the same AD with EAP, and compare RADIUS to the Kerberos and OIDC transports you've
  now seen.
- **Lab 13 (Monitoring)** — scrape the proxy's health and turn its logs into metrics.
- **Lab 16 (Capstone)** — a new hire's web traffic flows through this proxy, logged and
  policy-controlled, as one slice of the full stack.
