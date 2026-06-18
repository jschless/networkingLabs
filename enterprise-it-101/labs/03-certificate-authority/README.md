# Lab 03 — Certificate Authority & PKI

**Duration:** 2–3 hours

Back in Lab 01 the domain controller was already listening on port **636 (LDAPS)**, but you couldn't use it — there was no certificate, and AD refused to accept your password over the cleartext `ldap://` connection (you worked around it with Kerberos GSSAPI). This lab fixes that at the root: you stand up an **internal certificate authority** with [Smallstep `step-ca`](https://smallstep.com/docs/step-ca/), establish a chain of trust, issue the DC a real certificate, and turn on LDAPS. By the end, the simple bind that AD *rejected* in Lab 01 will succeed — over TLS — and you'll have proven on the wire that the difference is a complete, trusted certificate chain.

## Topology

```
┌────────────────────────────────────────────────────────────────────┐
│                       lab-corp  10.100.0.0/16                      │
│                                                                    │
│   ┌──────────────┐         ┌──────────────┐      ┌──────────────┐  │
│   │     ca1      │  issues  │     dc1      │      │   admin-ws   │ │
│   │   step-ca    │─────────▶│  Samba AD DC │◀─────│  Workstation │ │
│   │ 10.100.1.30  │  certs   │ 10.100.1.10  │ LDAPS│ 10.100.10.10 │ │
│   │ Root + Inter │          │  LDAPS :636  │ :636 │              │ │
│   │ HTTPS :9000  │◀─────────│ (now usable) │      │ trusts root  │ │
│   └──────────────┘ trust/   └──────────────┘      └──────────────┘ │
│                    issue          ▲ bootstrap trust ──┘            │
│        all three trust the CA's root certificate                   │
└────────────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `dc1` | `samba-ad:local` | `10.100.1.10` | Samba AD DC (auto-provisioned), LDAPS endpoint |
| `ca1` | `smallstep/step-ca:latest` | `10.100.1.30` | Internal certificate authority (root + intermediate) |
| `admin-ws` | `workstation:local` | `10.100.10.10` | Admin workstation — bootstraps trust, tests LDAPS |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective** and **hints** — your job is to figure out the commands. Then:

- **Predict before you run.** Each task asks you to commit to an answer first. Guessing wrong and finding out why is how the knowledge sticks.
- **Reveal the solution only after you've tried.** Commands are hidden behind `Solution` toggles. Lean on `step --help`, `step ca --help`, and `step certificate --help`.
- **Observe, don't just verify.** The `Check your work` toggles explain *why* an output means what it does — read them even when your command worked.

!!! note "`step` is your primary tool"
    The `step` CLI (Smallstep) is installed on `dc1` and `admin-ws`. It does
    everything: bootstrap trust (`step ca bootstrap`), issue certificates
    (`step ca certificate`), and inspect/verify them (`step certificate
    inspect|verify`). The CA daemon `step-ca` runs on `ca1`.

## Prerequisites

- **Lab 01** concepts (LDAP, the rejected cleartext simple bind) and **Lab 02** (a cert is only valid between its `notBefore`/`notAfter` — time matters here too).
- The custom images built:

```bash
cd enterprise-it-101
docker build -t samba-ad:local   images/samba-ad/
docker build -t workstation:local images/workstation/
```

You do **not** need a running Lab 01/02 — `dc1` auto-provisions and seeds the foundation (`alice`/`bob`/`charlie`, groups).

## Deploy

```bash
cd enterprise-it-101
docker compose -f base/docker-compose.yml \
               -f labs/03-certificate-authority/docker-compose.override.yml up -d
```

`dc1` provisions in ~10–20 s; `ca1` auto-initialises its root + intermediate CA on first boot. Watch with `docker logs -f ca1` until you see `Serving HTTPS on :9000`.

## Destroy

```bash
docker compose -f base/docker-compose.yml \
               -f labs/03-certificate-authority/docker-compose.override.yml down -v
```

---

## What is pre-built

- The `lab.corp` domain, auto-provisioned and seeded on `dc1`.
- An internal CA on `ca1`, auto-initialised (root + intermediate, JWK provisioner `admin`, listening on `:9000`). In production you'd run `step ca init` yourself — here it's done at boot so the CA is reliably healthy.
- `dc1` already points its resolver at the Samba DNS (so it can resolve `ca1.lab.corp` once you add the record).

## What you configure

You inspect the CA and learn its trust model, make it resolvable, **establish trust** on the clients, **issue** the DC a certificate, turn on **LDAPS**, prove it on the wire, then **break the trust chain** and diagnose a failure whose error message lies to you about its cause.

---

## Task 1 — Examine the CA you were handed

**Objective:** Understand the trust model before you use it. Inspect the CA's certificates and capture the one value every client needs to trust it: the **root fingerprint**.

??? question "Predict first"
    `step-ca` created **two** CA certificates, not one: a *root* and an *intermediate*. When `ca1` issues `dc1` a certificate, which of the two signs it — and why would a CA deliberately keep the root from signing leaf certificates directly?

??? note "Hints"
    - The CA's certs live in `/home/step/certs/` inside `ca1`: `root_ca.crt` and `intermediate_ca.crt`.
    - `step certificate inspect <file> --short` summarises subject/issuer/validity.
    - `step certificate fingerprint /home/step/certs/root_ca.crt` prints the SHA-256 fingerprint. **Copy it — you need it in Task 3.**

??? note "Solution"
    ```bash
    docker exec ca1 step certificate inspect /home/step/certs/root_ca.crt --short
    docker exec ca1 step certificate inspect /home/step/certs/intermediate_ca.crt --short

    # The fingerprint clients use to pin trust:
    docker exec ca1 step certificate fingerprint /home/step/certs/root_ca.crt
    ```

??? success "Check your work"
    The **root** is self-signed (`Subject` == `Issuer` == `Lab Corp CA Root CA`); the **intermediate** is signed *by* the root (`Issuer: …Root CA`, `Subject: …Intermediate CA`). The fingerprint is a 64-hex-character SHA-256 hash, unique to *this* deployment (a fresh `down -v` makes a new root).

    Your prediction: the **intermediate** signs leaf certificates. The root's private key is the crown jewels — compromise it and every certificate it ever signs (and the whole chain of trust) is forfeit, with no way to recover except replacing the root on every client. So the root signs exactly one thing — the intermediate — and is then meant to be kept offline. The intermediate does the day-to-day issuing and *can* be rotated without re-establishing trust everywhere. This two-tier design is why "internal PKI" isn't just "one self-signed cert."

---

## Task 2 — Make the CA resolvable

**Objective:** Add a DNS A record so `ca1.lab.corp` resolves across the lab. Trust bootstrap (next task) connects to the CA *by name*, and the certificate's name must match — so DNS comes first.

??? question "Predict first"
    The CA's HTTPS endpoint certificate has a SAN list of `ca1.lab.corp, ca1, localhost, 127.0.0.1`. If you tried to bootstrap trust using `--ca-url https://10.100.1.30:9000` (the raw IP) instead of the name, would it work? Why or why not?

??? note "Hints"
    - Use `samba-tool dns add` on `dc1`. Grammar: `samba-tool dns add <server> <zone> <name> <type> <data> -U Administrator`.
    - Here: server `127.0.0.1`, zone `lab.corp`, name `ca1`, type `A`, data `10.100.1.30`.
    - Verify resolution from both `dc1` and `admin-ws` with `getent hosts ca1.lab.corp`.

??? note "Solution"
    ```bash
    docker exec dc1 samba-tool dns add 127.0.0.1 lab.corp ca1 A 10.100.1.30 \
        -U Administrator --password='P@ssw0rd1'

    docker exec dc1       getent hosts ca1.lab.corp     # -> 10.100.1.30
    docker exec admin-ws  getent hosts ca1.lab.corp     # -> 10.100.1.30
    ```

??? success "Check your work"
    Both hosts resolve `ca1.lab.corp` to `10.100.1.30`. Your prediction: using the raw **IP** would *fail* trust bootstrap, because `10.100.1.30` is not in the cert's SAN list — TLS verification matches the hostname you connect to against the certificate's names, and an IP that isn't listed is a mismatch. Certificates bind trust to **names**, which is exactly why a PKI depends on DNS being correct. (This is also the seed of a classic outage: a renamed or re-IP'd service whose certificate no longer matches.)

---

## Task 3 — Establish the chain of trust

**Objective:** Make `admin-ws` and `dc1` trust the CA's root, and install it into the OS trust store so ordinary tools (`openssl`, `ldapsearch`) trust certificates the CA issues.

??? question "Predict first"
    You'll bootstrap trust *before* `dc1` has any certificate and *before* LDAPS is configured. After this task, if you run `ldapsearch -H ldaps://dc1.lab.corp …`, will it succeed? Predict the outcome and the reason.

??? note "Hints"
    - `step ca bootstrap --ca-url https://ca1.lab.corp:9000 --fingerprint <FP> --install` downloads the root (verifying it against your fingerprint) and, with `--install`, adds it to the OS trust store (`update-ca-certificates`).
    - Use the fingerprint from Task 1.
    - Do this on **both** `admin-ws` (it will test LDAPS) and `dc1` (it needs to trust `ca1` to request a cert in Task 4).
    - Confirm with `step ca health --ca-url https://ca1.lab.corp:9000`.

??? note "Solution"
    ```bash
    FP=<paste the fingerprint from Task 1>

    docker exec admin-ws step ca bootstrap --ca-url https://ca1.lab.corp:9000 \
        --fingerprint "$FP" --install
    docker exec dc1       step ca bootstrap --ca-url https://ca1.lab.corp:9000 \
        --fingerprint "$FP" --install

    docker exec admin-ws step ca health --ca-url https://ca1.lab.corp:9000   # -> ok
    ```

??? success "Check your work"
    Both report `Installing the root certificate in the system truststore... done.` and `step ca health` returns `ok`.

    Your prediction: `ldapsearch -H ldaps://…` still **fails** — but *not* because of trust. The clients now trust the CA, yet `dc1` is still presenting its default self-signed Samba certificate (or nothing usable), and you haven't enabled your cert. Trust is necessary but not sufficient: you need **both** a trusted issuer *and* the server actually presenting a cert from that issuer. You supply the second half in Tasks 4–5.

    The `--fingerprint` matters: bootstrap downloads the root over HTTPS but has no prior reason to trust it, so it checks the downloaded root against the fingerprint *you* supply out-of-band. That's the bootstrapping-trust problem solved by a single pinned hash.

---

## Task 4 — Issue the domain controller a certificate

**Objective:** From `dc1`, request a certificate for `dc1.lab.corp` from the CA and place it where Samba expects its TLS material.

??? question "Predict first"
    `step ca certificate dc1.lab.corp …` will ask for a password before it issues anything. *Whose* password is it asking for, and what would happen to your CA's security if certificate issuance required no authentication at all?

??? note "Hints"
    - `step ca certificate <name> <crt-out> <key-out> --provisioner admin --ca-url https://ca1.lab.corp:9000 --root /root/.step/certs/root_ca.crt`.
    - The provisioner `admin`'s password is `P@ssw0rd1` (it will prompt; or use `--provisioner-password-file`).
    - Write the files into `/var/lib/samba/private/tls/` (create it). Samba will read them from there.
    - Also copy the bootstrapped root to `ca.crt` in that directory — Samba references it as the `tls cafile`.

??? note "Solution"
    ```bash
    docker exec -it dc1 bash

    mkdir -p /var/lib/samba/private/tls
    step ca certificate dc1.lab.corp \
        /var/lib/samba/private/tls/dc1.crt \
        /var/lib/samba/private/tls/dc1.key \
        --provisioner admin \
        --ca-url https://ca1.lab.corp:9000 \
        --root /root/.step/certs/root_ca.crt
    # enter provisioner password: P@ssw0rd1

    cp /root/.step/certs/root_ca.crt /var/lib/samba/private/tls/ca.crt

    # Inspect what you got:
    step certificate inspect /var/lib/samba/private/tls/dc1.crt --short
    ```

??? success "Check your work"
    `step certificate inspect … --short` shows `Subject: dc1.lab.corp`, `Issuer: Lab Corp CA Intermediate CA`, and a validity window (default ~24 h — short by design; renewal is part of the lifecycle). The output file actually contains **two** PEM blocks — the leaf *and* the intermediate — so the server can present the full chain to clients (a leaf without its intermediate is the single most common "but it works in my browser / not in `curl`" trust bug).

    Your prediction: it asks for the **provisioner's** password (`admin`). Issuance must be authenticated — an unauthenticated CA would mint a valid `dc1.lab.corp` (or `bank.example.com`) certificate for *anyone who asked*, which is the entire threat a CA exists to prevent. The provisioner is how the CA decides *who* may request *what*.

---

## Task 5 — Turn on LDAPS and prove it on the wire

**Objective:** Configure Samba to use your certificate, restart it, and confirm from `admin-ws` that LDAPS now works — including the **simple bind that AD rejected in Lab 01**.

??? question "Predict first"
    In Lab 01, `ldapsearch -x … -D "alice@lab.corp" -w 'P@ssw0rd1'` over `ldap://` was rejected with *"Strong(er) authentication required … Transport encryption required."* Over `ldaps://` with a trusted cert, predict: does that exact same simple bind now succeed? Why did AD refuse it before?

??? note "Hints"
    - Add four lines inside the `[global]` section of `/etc/samba/smb.conf` on `dc1` (a ready-to-copy reference is mounted at `/root/smb-tls.conf`):

      ```
      tls enabled  = yes
      tls keyfile  = /var/lib/samba/private/tls/dc1.key
      tls certfile = /var/lib/samba/private/tls/dc1.crt
      tls cafile   = /var/lib/samba/private/tls/ca.crt
      ```
    - Apply with `supervisorctl restart samba`, then confirm `:636` is listening (`ss -tlnp | grep 636`).
    - From `admin-ws`: `openssl s_client -connect dc1.lab.corp:636` shows what the server presents and whether your OS trusts it. Then run the Lab 01 simple bind, but with `ldaps://`.

??? note "Solution"
    ```bash
    # On dc1 — edit smb.conf (vim), or insert the reference snippet after [global]:
    docker exec dc1 sed -i '/^\[global\]/r /root/smb-tls.conf' /etc/samba/smb.conf
    docker exec dc1 supervisorctl restart samba
    docker exec dc1 bash -c 'ss -tlnp | grep 636'

    # On admin-ws — inspect the served chain, then bind over TLS:
    docker exec admin-ws bash -c 'echo | openssl s_client -connect dc1.lab.corp:636 \
        2>/dev/null | grep -E "subject=|issuer=|Verify return code"'

    docker exec admin-ws ldapsearch -x -H ldaps://dc1.lab.corp -b "DC=lab,DC=corp" \
        -D "alice@lab.corp" -w 'P@ssw0rd1' "(sAMAccountName=alice)" dn memberOf
    ```

??? success "Check your work"
    `openssl s_client` reports `subject=CN = dc1.lab.corp`, `issuer=…Intermediate CA`, and crucially **`Verify return code: 0 (ok)`** — your OS walked the chain to the root you installed in Task 3 and trusted it. The `ldapsearch` **succeeds** (`result: 0 Success`) and returns alice's DN and `memberOf`.

    Your prediction: yes — the *identical* simple bind that failed in Lab 01 now works. AD's rule was never "no passwords"; it was **"no passwords over an unprotected channel."** Lab 01's `ldap://` was cleartext, so AD refused (`Transport encryption required`). LDAPS wraps the same LDAP in TLS, so the channel is encrypted and AD accepts the credential. You've now removed the reason you needed the Kerberos GSSAPI workaround — though GSSAPI is still better for *automated* clients because it needs no stored password at all.

---

## Task 6 — Break it: snap the chain of trust

**Objective (required Break-It):** Everything works. Now break the *client's trust* — not the certificate, not the network — and diagnose a failure whose error message points at the wrong layer, then repair it.

??? question "Predict first"
    You'll remove the CA's root from `admin-ws`'s trust store. The `dc1` certificate is untouched and still valid. Predict the **exact error** `ldapsearch -H ldaps://…` produces. Will it mention certificates or trust at all?

**Break it** (on `admin-ws`). The root was installed as a file in the trust dir — remove it and refresh the bundle:

```bash
docker exec admin-ws bash -c '
  rm -f /usr/local/share/ca-certificates/Lab_Corp_CA_Root_CA_*.crt
  update-ca-certificates --fresh
  grep -c "Lab Corp" /etc/ssl/certs/ca-certificates.crt'   # -> 0
```

**Now diagnose from the client**, as if you didn't know what changed:

```bash
docker exec admin-ws ldapsearch -x -H ldaps://dc1.lab.corp -b "DC=lab,DC=corp" \
    -D "alice@lab.corp" -w 'P@ssw0rd1' dn
```

??? note "Diagnosis hints (try before revealing)"
    - The `ldapsearch` error talks about *contacting the server*. Is the server actually unreachable? Test the raw TLS layer instead of trusting the LDAP error:
      ```bash
      docker exec admin-ws bash -c 'echo | openssl s_client -connect dc1.lab.corp:636 2>/dev/null | grep "Verify return code"'
      ```
    - Compare what `openssl` says about the certificate vs. what `ldapsearch` claims about connectivity. Which layer is *really* failing?

??? success "What you should observe"
    `ldapsearch` fails with:

    ```
    ldap_sasl_bind(SIMPLE): Can't contact LDAP server (-1)
    ```

    which sounds like a **network** problem — but `dc1` is up and `:636` is listening. `openssl s_client` tells the truth:

    ```
    Verify return code: 20 (unable to get local issuer certificate)
    ```

    The certificate `dc1` presents is **perfectly valid and unchanged**; the client simply no longer trusts its issuer, so the TLS handshake aborts — and OpenLDAP reports that aborted handshake as the misleading "Can't contact LDAP server." This is the essence of a trust-chain outage: *the certificate is fine, the trust is gone*, and the surface error blames the wrong layer. In production this is the "it works on my machine" cert bug — the missing root (or intermediate) is on the **client**, not the server.

**Repair it:**

```bash
docker exec admin-ws bash -c '
  cp /root/.step/certs/root_ca.crt /usr/local/share/ca-certificates/lab-corp-root.crt
  update-ca-certificates'
docker exec admin-ws ldapsearch -x -H ldaps://dc1.lab.corp -b "DC=lab,DC=corp" \
    -D "alice@lab.corp" -w 'P@ssw0rd1' "(sAMAccountName=alice)" dn   # -> Success again
```

---

## Verification Checklist

```bash
# CA is healthy and trusted
docker exec admin-ws step ca health --ca-url https://ca1.lab.corp:9000          # ok

# dc1 serves a CA-issued cert that the client's OS trusts
docker exec admin-ws bash -c 'echo | openssl s_client -connect dc1.lab.corp:636 \
    2>/dev/null | grep -E "subject=|Verify return code"'                        # CN=dc1.lab.corp, code 0

# The Lab 01-rejected simple bind now succeeds over TLS
docker exec admin-ws ldapsearch -x -H ldaps://dc1.lab.corp -b "DC=lab,DC=corp" \
    -D "alice@lab.corp" -w 'P@ssw0rd1' "(sAMAccountName=alice)" dn               # result: 0 Success

# The chain validates explicitly
docker exec dc1 step certificate verify /var/lib/samba/private/tls/dc1.crt \
    --roots /var/lib/samba/private/tls/ca.crt && echo CHAIN-VALID
```

---

## Challenge Questions

No solutions provided — reason it through.

1. **Public CA vs. internal CA.** You could not buy a publicly-trusted certificate for `dc1.lab.corp` even with a budget. Why not? What property of public CAs makes `.corp` (and any internal-only name) un-issuable, and how does an internal CA sidestep it — at what cost?

2. **The intermediate's job.** Suppose your *intermediate* CA key is compromised but the root is safe (offline, as designed). Walk through how you'd recover: what do you revoke/replace, and — critically — do you have to re-install a new root on every client? Contrast with the root being compromised.

3. **Two ways to trust, two ways to fail.** A teammate's `ldaps://` works from `admin-ws` but fails from a brand-new container with `unable to get local issuer certificate`, while `openssl` on `dc1` shows the cert is valid. Where is the fault, and what single step fixes the new container? Now suppose instead the error were `certificate has expired` — what's different about where you'd look?

4. **Expiry is a time bomb (ties to Lab 02).** Your DC cert is valid ~24 h. Predict what breaks, and *when*, if nobody renews it — and what the symptom looks like to a user trying to log in through an LDAPS-dependent service. Why is "monitor certificate expiry" one of the highest-value alerts in an enterprise (preview of Lab 13)?

5. **Design extension.** Labs 09 (mail), 10 (Keycloak), and 12 (RADIUS/EAP-TLS) all need TLS certificates. Given the CA you just built, sketch how each would get one. What has to be true about *their* trust stores, and where would you put a wildcard `*.lab.corp` cert vs. per-service certs?

---

## Key Concepts

**A certificate is only as good as the trust behind it:**

| Piece | What it is | Failure if missing |
|-------|-----------|--------------------|
| Leaf cert (`dc1.lab.corp`) | Identity the server presents | Server can't prove who it is |
| Intermediate cert | Signs leaves; presented *with* the leaf | `unable to get local issuer certificate` |
| Root cert | Self-signed trust anchor, **on the client** | Client rejects the whole chain |
| Name match (SAN) | Cert names must match the host you dialed | Hostname-mismatch errors |
| Validity window | `notBefore`/`notAfter` | Expiry/clock-skew failures (Lab 02) |

**Why internal CAs exist:** public CAs only issue for names you can prove you control on the public internet, so `.corp` and other internal names can never get a public cert. An internal CA issues them freely — but *only the machines you configure* trust it, which is the trade-off.

**Two-tier PKI:** the root signs one thing (the intermediate) and goes offline; the intermediate does daily issuance and can be rotated without touching client trust. Compromise of the intermediate is recoverable; compromise of the root is catastrophic.

**The debugging tools:** `openssl s_client -connect host:port` shows what a server presents and whether *you* trust it (`Verify return code`); `step certificate inspect` reads any cert; `step certificate verify --roots` checks a chain. When `ldapsearch` says "Can't contact LDAP server," reach for `openssl s_client` — the real cause is often TLS trust, not the network.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `step ca bootstrap` → `no such host` | `ca1.lab.corp` not in DNS (Task 2 skipped) | Add the A record; check `getent hosts ca1.lab.corp` |
| `step ca bootstrap` → fingerprint mismatch | Wrong/old fingerprint (root changed on `down -v`) | Re-read it: `step certificate fingerprint /home/step/certs/root_ca.crt` |
| `step ca certificate` → `error parsing token`/auth | Wrong provisioner password | It's `P@ssw0rd1` for provisioner `admin` |
| `:636` not listening after restart | `smb.conf` TLS lines outside `[global]` or bad path | `testparm -s \| grep tls`; check file paths exist |
| `ldapsearch -H ldaps://` → `Can't contact LDAP server` | TLS trust failure (not network) | `openssl s_client …`; ensure root is installed (Task 3) |
| `openssl` → `unable to get local issuer certificate` | Root not in client trust store | `update-ca-certificates` after copying the root in |
| `openssl` → `certificate has expired` | Leaf past `notAfter` (~24 h default) | Re-issue with `step ca certificate` (renewal) |

---

## What's Next

- **Lab 04 (Domain Join)** — `ws1`/`ws2` join `lab.corp`; sssd talks to the DC over LDAP, and the trust you established here is the model for how every member trusts the domain's services.
- **Lab 09 (Email), Lab 10 (Keycloak SSO), Lab 12 (RADIUS/EAP-TLS)** — each gets its certificate from *this* CA. EAP-TLS in particular uses certificates for both ends, no passwords at all — the logical end point of "trust by certificate" you started here.
- **Lab 13 (Monitoring)** — you'll add a "certificate expiring within N days" alert, because (as Task 6 / challenge 4 show) a silently-expired cert is one of the most common and most preventable enterprise outages.
