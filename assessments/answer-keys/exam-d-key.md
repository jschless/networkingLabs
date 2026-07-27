# Exam D — Answer Key & Grading Notes

Almost every question here has the same shape underneath: **which link in the chain does
this evidence eliminate?** A candidate who reasons from "this worked, therefore these five
things are fine" is doing the thing the curriculum teaches. One who lists possible causes
without eliminating any is not.

---

## Section 1 — Concepts & mechanisms (30)

**D1 (3).**
- **LDAP** — the **directory**: reading and writing objects, attributes, group memberships,
  searches. It is how you *ask about* things.
- **Kerberos** — **authentication**: proving who you are and obtaining tickets that let you
  prove it to services without re-presenting a credential.
- **NTLM** — the **legacy challenge/response fallback**, still used when Kerberos cannot be
  (connecting by IP literal with no SPN, no DNS, workgroup members, some appliances). It is
  a fallback, not a peer.

The exchange, cold login to open share:
1. **AS-REQ / AS-REP** — client to the KDC's Authentication Service. The client gets a
   **TGT** (encrypted with the krbtgt key, opaque to the client) plus a **session key**
   encrypted under the user's own key.
2. **TGS-REQ / TGS-REP** — client presents the TGT and asks for a ticket for the file
   server's SPN (`cifs/fs1.lab.corp`). It gets a **service ticket** encrypted with the file
   server's key.
3. **AP-REQ / AP-REP** — client presents the service ticket to the **file server**, which
   decrypts it with its own long-term key.

**The thing the file server never receives: the user's password, or anything derived from
it.** It also never contacts the KDC to validate the ticket — it decrypts it locally. That
is the entire point.

*1 for the three protocols' roles, 1 for the three exchanges, 1 for the "no password ever
reaches the service" observation.*

**D2 (3).**
(a) **Replay.** The authenticator the client sends is encrypted with the session key and
contains a **client-generated timestamp**; the service checks it falls within the skew
window and keeps a **replay cache** covering that window. Without a bounded window the
replay cache would have to be infinite, so the five minutes is what makes replay protection
implementable at all.
(b) Everything that needs a **ticket** fails: `kinit` errors with "Clock skew too great",
domain file shares, LDAPS-with-GSSAPI, and SSO all break. What still works: purely local
accounts, cached-credential logins where configured, and plain IP-level networking — the
machine is *up* and on the network, which is exactly why it looks like an application
problem.
(c) Because the failure lands **at the password prompt** and higher layers usually surface
it as a generic "logon failure". The user then reports "my password stopped working", the
helpdesk resets the password, nothing changes, and the ticket escalates in the wrong
direction. The tell is that a *correct* password fails identically to a wrong one.

*1 per part.*

**D3 (3).**
(a) The **root key stays offline**; it signs only the intermediate. If the issuing CA is
compromised or needs to be rotated, you revoke and replace the **intermediate** — every
client keeps the same trust anchor and nothing needs redistributing. Issuing directly from
the root means a compromise forces you to re-establish trust on every device in the estate.
(b) `admin-ws` must hold the **root CA certificate as a trust anchor**, and the DC must
present the **intermediate** alongside its leaf so the client can build the chain
root → intermediate → leaf. For the hostname check, the DC's certificate must carry
**`dc1.lab.corp` in the Subject Alternative Name (`dNSName`)** — modern TLS clients ignore
the CN entirely.
(c) The DC now has a **certificate**, so LDAPS gives a confidential channel. AD rejected the
cleartext simple bind in Lab 01 precisely because it would have put the password on the
wire in the clear; inside TLS that objection disappears and the same bind is accepted.

*1 per part. For (b), an answer that says "CN" instead of SAN loses half that point.*

**D4 (3).**
(a) A client has no idea what the domain controllers are called. It finds them by looking up
**SRV records** — `_ldap._tcp.dc._msdcs.lab.corp`, `_kerberos._udp.lab.corp` — so the very
first thing it does, **before it can authenticate at all**, is a DNS lookup. This is why DNS
failures in an AD domain present as authentication failures.
(b) **Conditional forwarding** sends queries for one named zone to a specific server instead
of recursing for them. `dns1` forwards `lab.corp` to `dc1` rather than being authoritative
because **AD maintains that zone dynamically** — DCs register their own A and SRV records
via DDNS. A second authoritative copy would go stale and start handing out wrong DC
locations. One authoritative source; everyone else forwards.
(c) **Split-horizon** is serving different answers for the same name based on who is asking.
BIND implements it with **`view` statements**, selected by **`match-clients`** ACLs on the
query source address.

*1 per part.*

**D5 (3).**
(a) **DISCOVER, OFFER, REQUEST, ACK.** DISCOVER and REQUEST are **broadcast** — REQUEST
must be, so that servers whose offers were *not* chosen see it and release their
reservations. OFFER and ACK may be broadcast or unicast; they are commonly broadcast because
the client has no usable address yet.
(b) DDNS registers the client's **name → address** mapping in DNS as the lease is issued, so
the host becomes resolvable seconds after boot. In the Lab 06 design the update is performed
by **`kea-dhcp-ddns` (the D2 daemon)** — not by `kea-dhcp4` directly, and definitely not by
the client.
(c) **TSIG** signs the DNS UPDATE with an HMAC under a shared symmetric key, so the DNS
server can verify the update came from the authorised updater and was not tampered with.
Without it the zone would need `allow-update { any; }`, and anyone who could reach port 53
could **overwrite arbitrary records** — repoint `dc1.lab.corp`, or a mail or proxy name, at
a host they control. In a domain where every service is located via DNS and every trust
decision starts with a name, that is a complete compromise, not a nuisance.

*1 per part. Award (c) generously for anyone who reaches "you could repoint a service name
and harvest credentials".*

**D6 (3).**
(a) The **share-level permissions** in the Samba share definition (`valid users`,
`read only`, `write list`) and the **filesystem POSIX permissions / ACLs** on the underlying
directory. Both must permit the operation; **the more restrictive one wins** — effective
access is the intersection. Neither can grant what the other denies.
(b) Mounting **with Kerberos** (`sec=krb5`) means the client presents a **service ticket**
for the `cifs/` SPN instead of a password or an NTLM hash. It avoids transmitting or storing
any reusable credential, gives real single sign-on, and removes the NTLM fallback path.
(c) Because **group membership is stamped into the Kerberos ticket (the PAC) when the ticket
is issued**. Adding the user to a group does not retroactively rewrite tickets they already
hold; they keep presenting a ticket whose group list predates the change. Logging out and
back in destroys the cache and forces a fresh TGT — which is the only reason the "turn it
off and on again" folklore actually works here.

*1 per part. (c) recurs as the Section 5 scenario — a candidate who gets it here and misses
it there should be marked down there, not here.*

**D7 (3).**
(a) **GPO is pull**: the domain-joined client fetches policy from SYSVOL on its own
schedule — at boot and logon, then roughly every 90 minutes with a random offset. **Ansible
is push**: a control node opens a connection outward (SSH/WinRM) and runs the playbook when
a human or a scheduler invokes it.
(b) **GPO better for:** things scoped to AD structure and to a user's logon session — drive
mappings, logon scripts, per-user security and desktop settings that must follow the user to
any machine, applied automatically to anything dropped into the OU. **Ansible better for:**
anything non-Windows or not domain-joined, ordered multi-host orchestration, installing and
configuring arbitrary software with dependencies, and anything you want reviewed in version
control.
(c) On a hand-made change: **GPO silently reapplies** at the next refresh, so drift
self-heals within ~90 minutes and **nobody ever learns it happened**. **Ansible does nothing
until the next run**, and then reports `changed` — so drift persists longer but is
**visible**. Continuous-and-invisible versus intermittent-and-auditable is the real
trade-off, and a candidate who frames it that way should get full marks.

*1 per part.*

**D8 (3).**

| | Proves | Does not prove | Checked against |
|---|---|---|---|
| **SPF** | The **connecting IP** is authorised to send for that domain | That the message is unmodified, or anything about the address the user sees | The **envelope sender** (`MAIL FROM` / Return-Path) |
| **DKIM** | The signed headers and body **were not altered** and were signed by a key published in the signing domain's DNS | Who connected, or from where | The **`d=` domain** in the DKIM-Signature header |
| **DMARC** | That SPF or DKIM **aligns** with the address the user actually sees, plus publishes a policy and reporting | That the content is benign | The **header `From:`** |

**DKIM survives forwarding and SPF usually does not** because forwarding changes the
**connecting IP** — the forwarder becomes the sender, so SPF for the original domain fails
unless the envelope sender is rewritten (SRS). DKIM signs the **message content**, which a
plain forwarder relays byte-for-byte, so the signature still verifies. The exception worth
mentioning: mailing lists that add subject tags or footers **modify** the message and break
DKIM too.

*2 for the table, 1 for the forwarding explanation.*

**D9 (3).**
(a) The user hits the app; the app **redirects the browser** to Keycloak's authorization
endpoint; **the user enters credentials at Keycloak**, never at the app; Keycloak redirects
the browser back to the app's registered redirect URI carrying a short-lived
**authorization code**; the app then **exchanges that code at the token endpoint over a
back channel** (server-to-server, authenticated with its client secret) for tokens. The code
travels through the browser; the tokens do not.
(b) **ID token** — audience is **the app**; a signed JWT asserting *who the user is*
(subject, name, groups) and how and when they authenticated. **Access token** — audience is
a **resource/API**; a bearer credential asserting *what may be done*. The app must validate
the ID token's signature, issuer, and audience, and must not use an ID token as a bearer
token nor treat an access token as proof of identity.
(c) The app never sees the password because the credential is only ever entered on
**Keycloak's own login page**. Keycloak never stores one because it is **federated to AD
over LDAP** and delegates the check to AD with a bind — it holds no password of its own.
(d) **Keycloak enforces TOTP**, as an extra step inside its own authentication flow. The app
needs no change because MFA happens entirely on the IdP's side of the redirect: the app's
contract is unchanged — it redirects and receives a token. (A sophisticated app may inspect
`acr`/`amr` claims if it cares *how* the user authenticated.)

*0.75 per part, rounded in the candidate's favour.*

**D10 (3).**

| Method | What the RADIUS server does | AD interface used |
|---|---|---|
| **PAP** | Receives the password (obscured only by the RADIUS shared secret) and performs an **LDAP bind to AD as that user** — success of the bind is the authentication. | **LDAP / LDAPS** |
| **PEAP/MSCHAPv2** | Builds a TLS tunnel (server certificate only), runs MSCHAPv2 challenge/response inside it, and hands the challenge/response to **`ntlm_auth`**, which validates it against AD using the server's **machine account**. This is why `radius1` must be domain-joined. | **winbind / netlogon (SMB), via the machine account** |
| **EAP-TLS** | Validates the **client certificate** against the trusted CA — no password exists anywhere in the exchange — then maps the certificate identity (SAN/UPN) to an AD user, usually with an LDAP lookup for **authorisation** (group → VLAN). | **LDAP, for authorisation only** |

**Shared-secret / client mismatch fails silently** because a RADIUS server **discards**
packets it cannot attribute to a configured client rather than replying. Replying would be
an oracle telling an attacker whether they had guessed a valid client or secret. From the
**NAS**: a timeout and retries, no response at all. From the **server**: a log line saying
the request was ignored — from an unknown client, or with an invalid Message-Authenticator
("shared secret is incorrect") — and no accounting of the attempt.

*1 per method row, capped at 2; 1 for the silent-failure explanation covering both ends.*

---

## Section 2 — Evidence reading (20)

### D-E1 (7)

(a) *(3)* **chrony has never synchronised, so the workstation's clock is free-running and
has drifted past Kerberos's five-minute tolerance.** Three independent confirmations in the
output: `Stratum 0` with a **Ref time of the Unix epoch** (it has never had a reference),
`Leap status: Not synchronised`, and — the decisive one — **`Reach 0`**, meaning the
reachability register is empty: **not a single response has ever been received from
`ntp1`**. The **`^?`** marker says the same thing: a source whose state is unknown because it
has never answered. This is not "the clock is slightly off"; it is "time was never
configured or the server was never reachable".

*2 for the diagnosis, 1 for correctly reading `Reach 0` / `^?` as "no responses ever
received". A candidate who says the clock is merely drifting has not used the evidence.*

(b) *(2)* **Entirely consistent — the password was never evaluated.** The KDC rejected the
request on the timestamp before the credential mattered, and `kinit` returns
`Clock skew too great` for a correct and an incorrect password alike. Note the message is
distinct from `Preauthentication failed`, which is what a genuinely wrong password produces
— that difference is the fastest way to tell the two apart, and a candidate who cites it
should get full marks.

(c) *(2)* Two candidates:
1. **`ntp1` is not serving** — chrony not running, or its `allow` ACL does not cover the lab
   subnet, so requests arrive and are ignored.
2. **The client cannot reach it** — `ntp1.lab.corp` does not resolve, or UDP/123 is not
   getting through.

**Separating check:** resolve and probe from the client first —
`getent hosts ntp1.lab.corp` followed by a direct query (`chronyc -N sources`,
`ntpdate -q ntp1.lab.corp`). Name does not resolve → DNS. Resolves and pings but no NTP
response → server side; confirm with **`chronyc clients` on `ntp1`**, which shows whether
requests are arriving at all — that single command puts the fault on one side of the wire or
the other.

### D-E2 (7)

(a) *(3)* **The client cannot build a chain to a trusted root.**
`unable to get local issuer certificate` means `admin-ws` does not hold the CA's root as a
trust anchor (and/or the DC is not presenting the intermediate). **The fault is at the
client**, in the trust store — not on the DC, which is listening and serving a valid
certificate.

The evidence that makes this certain rather than probable: **both attempts fail identically,
including the one by IP address.** Chain building happens **before** hostname verification,
so a naming problem would produce a *different* error — and would not produce the same
issuer error for both forms.

*2 for naming the trust failure and locating it at the client; 1 for using the
FQDN-and-IP-fail-identically observation. That observation is the graded reasoning.*

(b) *(2)* Install the CA root as a trust anchor on `admin-ws`:
**`step ca bootstrap --ca-url https://ca1.lab.corp:9000 --fingerprint <root-fingerprint>`**,
followed by **`step certificate install`** (or copying the root into
`/usr/local/share/ca-certificates/` and running `update-ca-certificates`, and/or pointing
`TLS_CACERT` in `ldap.conf` at it) so that OpenLDAP's TLS stack — not just `step` — trusts
it. The out-of-band **fingerprint** is the actual trust anchor; that is what `bootstrap`
exists to verify. Also confirm the DC serves the **intermediate** with its leaf so the chain
is complete.

*1 for the bootstrap, 1 for getting the root into the store the LDAP client actually
consults. A candidate who only runs `step ca bootstrap` and stops has a very common
half-fix.*

(c) *(2)* It would tell you that **trust is now fixed** — the chain validates, which is why
the error advanced to the *next* check — and that the certificate's **Subject Alternative
Name does not contain `dc1.lab.corp`**. Most likely it was issued for a different name, or
it has only a CN and no SAN at all, which modern clients ignore outright. Inspect the
**SAN (`dNSName`) extension**, e.g. `step certificate inspect`. The IP form would still fail
for a related but separate reason: there is no **`iPAddress` SAN** entry for `10.100.1.10` —
you would need to add one, or simply always connect by name.

### D-E3 (6)

(a) *(2)* **`nas1` (10.100.20.11) is not defined as a client on the RADIUS server.** The log
says so verbatim: *"Ignoring request … from unknown client 10.100.20.11"*. The RADIUS server
will not process a request from a source address it has no `client` block for, regardless of
the secret offered.

*Accept "shared secret / client definition problem" for full marks; the log names the
unknown-client variant specifically, so a candidate who says only "wrong shared secret"
scores 1 — the distinction between the two is exactly what part (b) is testing.*

(b) *(2)* Because the server **discards the packet without generating a response**. That is
deliberate: replying would be an oracle confirming to an attacker which source addresses and
secrets are recognised.

Diagnostically it is worth a great deal, because it **partitions the search space in one
observation**:
- **Timeout** → the request was never accepted for processing. Look at `clients.conf`, the
  shared secret, the destination IP/port, or a firewall.
- **Access-Reject** → the server accepted, decoded, and *evaluated* the request. The
  transport and the client definition are all fine; the problem is the credential, the AD
  path, or the policy.

Nothing else in the RADIUS toolchain tells you that much for free.

(c) *(2)* Correct **`configs/clients.conf`** on `radius1`, adding a block for the NAS:

```text
client nas1 {
    ipaddr = 10.100.20.11
    secret = testing123
    require_message_authenticator = no
}
```

Afterwards you must **restart `radius1`** — `docker compose … restart radius1` — because
**FreeRADIUS reads its configuration only at startup**, and in this lab the restart also
re-runs the domain join and reload. Editing the bind-mounted file changes nothing on its
own.

*1 for the file and content, 1 for the restart requirement. The restart is the half
candidates forget, and it is called out explicitly in the lab README.*

---

## Section 3 — Implementation on paper (25)

### D-C1 (9) — DC certificate and LDAPS

Ordered procedure:

1. **Bootstrap trust — on both `dc1` and `admin-ws`** *(2)*
   `step ca bootstrap --ca-url https://ca1.lab.corp:9000 --fingerprint <root-fp>`, then
   `step certificate install $(step path)/certs/root_ca.crt` so the **system** trust store
   (which OpenLDAP consults) has it, not just the `step` profile. The **fingerprint obtained
   out of band** is the trust anchor; that is the whole security argument of the step.
2. **Issue the certificate — on `dc1`** *(2)*
   `step ca certificate dc1.lab.corp <cert> <key> --san dc1.lab.corp --san lab.corp`
   (add `--san 10.100.1.10` if anything will connect by IP). It must be issued **for the
   name clients will use**, and that name must land in the **SAN (`dNSName`)** — a CN alone
   will not satisfy a modern client.
3. **Install and point Samba at it — on `dc1`** *(2)*
   Place cert, key, and the CA chain where Samba expects them (e.g.
   `/var/lib/samba/private/tls/`), set `tls enabled = yes`, `tls certfile`, `tls keyfile`,
   `tls cafile` in `smb.conf`, and restrict the key to mode `0600` owned by root.
4. **Restart Samba** *(1)* — TLS material is read at startup.
5. **Verify the connection** *(1)*
   `ldapsearch -H ldaps://dc1.lab.corp -D "alice@lab.corp" -W -b "dc=lab,dc=corp" "(cn=alice)"`
   — and note *why* this is the right test: it is a **simple bind**, the exact operation AD
   refused in Lab 01.
6. **Verify the chain, not just the connection** *(1)*
   `openssl s_client -connect dc1.lab.corp:636 -showcerts -CAfile root_ca.crt` and confirm
   `Verify return code: 0 (ok)` **and** that the intermediate was presented; or
   `step certificate inspect` the served certificate and check the SAN and `notAfter`. A
   successful `ldapsearch` proves the client trusts *something*; this proves the chain is
   complete and correctly named.

**Validity window, given Lab 02** *(implicit in the marks above — award back a lost point
for a good answer)*: `step-ca` issues **short-lived certificates by default**, and a
certificate is only valid between `notBefore` and `notAfter`. So a skewed clock rejects a
perfectly good certificate as not-yet-valid or already expired. **Time is a dependency of
PKI exactly as it is of Kerberos** — the same Lab 02 failure, wearing a different error
message.

### D-C2 (8) — BIND9 views

```text
acl internal { 10.100.0.0/16; localhost; };

view "internal" {
    match-clients { internal; };
    recursion yes;
    allow-recursion { internal; };
    forwarders { 1.1.1.1; };

    // more specific than lab.corp, so it wins
    zone "www.lab.corp" IN { type master; file "/etc/bind/db.www.internal"; };

    // everything else in lab.corp goes to the AD DC
    zone "lab.corp" IN {
        type forward;
        forward only;
        forwarders { 10.100.1.10; };
    };

    include "/etc/bind/named.conf.default-zones";
};

view "external" {
    match-clients { any; };        // MUST be last
    recursion no;

    zone "www.lab.corp" IN { type master; file "/etc/bind/db.www.external"; };
};
```

Scoring (8):
- 2 — two views with `match-clients` doing the client selection
- 2 — the conditional forward zone for `lab.corp` pointing at `10.100.1.10` with
  `forward only`
- 2 — the **more-specific `www.lab.corp` zone overriding the forward zone**. BIND selects
  the most specific matching zone, which is what makes split-horizon and conditional
  forwarding coexist. A candidate who forwards all of `lab.corp` and then wonders where
  their internal `www` answer went has missed the mechanism — 0 for this item.
- 1 — recursion enabled and restricted to internal, disabled externally
- 1 — **the ordering rule**: views are matched **in the order written, first match wins**, so
  a view with `match-clients { any; }` must come **last** or it swallows every query.
  (Bonus-worthy: once *any* view exists, **every** zone must live inside a view.)

### D-C3 (8) — Kea + TSIG DDNS

**Kea DHCPv4:**

```json
{ "Dhcp4": {
  "subnet4": [ {
    "id": 1,
    "subnet": "10.100.10.0/24",
    "pools": [ { "pool": "10.100.10.50 - 10.100.10.99" } ],
    "option-data": [
      { "name": "routers",             "data": "10.100.10.1" },
      { "name": "domain-name-servers", "data": "10.100.1.40" },
      { "name": "ntp-servers",         "data": "10.100.1.20" },
      { "name": "domain-name",         "data": "lab.corp"    }
    ],
    "ddns-qualifying-suffix": "dhcp.lab.corp"
  } ],
  "ddns-send-updates": true,
  "dhcp-ddns": { "enable-updates": true,
                 "server-ip": "127.0.0.1", "server-port": 53001 }
} }
```

**Kea D2 (`kea-dhcp-ddns.conf`):**

```json
{ "DhcpDdns": {
  "ip-address": "127.0.0.1", "port": 53001,
  "tsig-keys": [ { "name": "dhcp-key", "algorithm": "HMAC-SHA256",
                   "secret": "<base64>" } ],
  "forward-ddns": { "ddns-domains": [ {
      "name": "dhcp.lab.corp.", "key-name": "dhcp-key",
      "dns-servers": [ { "ip-address": "10.100.1.40" } ] } ] },
  "reverse-ddns": { "ddns-domains": [ {
      "name": "10.100.10.in-addr.arpa.", "key-name": "dhcp-key",
      "dns-servers": [ { "ip-address": "10.100.1.40" } ] } ] }
} }
```

**BIND side (`dns1`):**

```text
key "dhcp-key" { algorithm hmac-sha256; secret "<same base64>"; };

zone "dhcp.lab.corp" IN {
    type master; file "/var/lib/bind/db.dhcp.lab.corp";
    allow-update { key "dhcp-key"; };
};
zone "10.100.10.in-addr.arpa" IN {
    type master; file "/var/lib/bind/db.10.100.10";
    allow-update { key "dhcp-key"; };
};
```

Scoring (8): 2 — pool and the four options; 2 — DDNS enabled on both the DHCP4 side and D2
with forward **and** reverse domains; 2 — the TSIG key defined **on both sides with the same
name, algorithm, and secret** (a mismatch in any of the three fails, and the name matters);
1 — `allow-update { key … }` rather than an address-based ACL; 1 — naming the right actor.

**Which component sends the DNS UPDATE:** **`kea-dhcp-ddns` (D2)**. `kea-dhcp4` sends it an
internal Name Change Request on port 53001; D2 constructs and signs the actual DNS UPDATE.
Neither the DHCP client nor `kea-dhcp4` talks to `dns1`. A candidate who says "the client"
or "the DHCP server directly" loses this point.

---

## Section 4 — Design & trade-offs (15)

### D-D1 (8)

(a) *(4)* Order, each justified by its dependency:
1. **`ntp1` — time.** Everything downstream depends on it: Kerberos's five-minute window,
   every certificate's validity check, and log correlation across the estate. Bringing it up
   after the DC risks the DC issuing tickets from a wrong clock.
2. **`dc1` — AD DNS, Kerberos, LDAP.** It holds the SRV records nothing can find a KDC
   without, and it *is* the KDC. Nothing that authenticates can start before it.
3. **`ca1` — the CA.** Needed before anything wants a fresh certificate, and itself
   dependent on correct time.
4. **`dns1` — resolver.** Conditionally forwards `lab.corp`, so it needs `dc1` answering.
5. **`dhcp1`.** Needs DNS for its DDNS updates.
6. **Member services** — file, mail, proxy, RADIUS, Keycloak — all depend on identity, name
   resolution, and certificates.
7. **Monitoring, SIEM, backup.** They observe the rest. *Accept a candidate who brings
   monitoring up early to watch the recovery; that is a defensible operational choice and
   should be rewarded if argued.*

*4 for an order with a stated dependency per position. Time first and identity second are
the two placements that must be right; a candidate who starts anywhere else caps at 2.*

(b) *(3)* With the intermediate expired, what breaks — roughly in the order you notice it:
- **LDAPS** — Keycloak's AD federation, the proxy's auth, any tooling doing simple binds.
  **Presents as "SSO is down" / "nobody can log in."**
- **RADIUS EAP-TLS and PEAP** — the server's own certificate is invalid and validating
  supplicants refuse it. **Presents as "Wi-Fi/802.1X is broken", and often as a password
  problem.**
- **Mail TLS (SMTP/IMAP)** — clients refuse to connect. **Presents as "Outlook can't
  connect."**
- **HTTPS endpoints and the proxy** — browser warnings; at least this one looks like what it
  is.
- **New certificate issuance** — step-ca will not issue from an expired intermediate.
  Presents as "the automation is broken".

**The ones that do not present as certificate problems** are the first three: login
failures, 802.1X failures, and mail connection failures all look like identity or network
faults. That is the graded observation — 1 of the 3 marks is for naming them as such.

(c) *(1)* **Backup.** Nobody files a ticket about a backup that did not run, because nothing
they touch is affected — right up until the restore, at which point the outage is permanent
rather than inconvenient. *Accept **monitoring/SIEM** with the argument that a silent
monitoring outage also removes your ability to notice the next outage and destroys the audit
trail; backup is the stronger answer.*

### D-D2 (7)

(a) *(3)*
- **AD database — application-consistent, mandatory.** Back up the Samba directory state:
  the `*.ldb` files under `/var/lib/samba/private`, **SYSVOL** (GPOs and scripts), the
  secrets/keytab material, and `smb.conf`. The LDB files are a **live transactional
  database**; a crash-consistent file copy can capture a torn write mid-transaction that
  simply will not load. Use the supported path — `samba-tool domain backup` — which quiesces
  and produces a loadable snapshot.
- **CA private key — crash-consistent is acceptable.** Back up the root and intermediate
  **keys**, the CA configuration (`ca.json`) and provisioners, and the issuance database. The
  key file is small and not being written, so consistency is not the hard problem here —
  **secrecy is**. It is the one secret whose disclosure retroactively compromises every
  certificate ever issued, so the interesting requirements are encryption at rest and
  offline custody, not snapshot semantics.

*Full marks require the "transactional database vs static file" reasoning, not just the
labels.*

(b) *(2)* The bootstrapping problem: the backup repository is encrypted with a passphrase,
and if you store that passphrase **inside the estate** — in AD, on the file share, or in a
password manager that authenticates against AD — then **losing the estate loses the ability
to decrypt the backups that would restore it.** It is a circular dependency, and it is the
single most common way a technically perfect backup regime turns out to be worthless.

Solve it by keeping the repository passphrase and the CA key's passphrase **outside the
systems they protect**: sealed offline, in a hardware token, or escrowed somewhere with
genuinely independent authentication — and documented in a disaster-recovery runbook that is
itself stored offline. Then verify that the person actually on call can reach it at 3 a.m.,
which is a different question from whether it exists.

(c) *(2)* A restore test that proves something: restore the AD database **to an isolated
network** rather than over the live DC, bring it up, and then **exercise what you actually
need** — `kinit alice` succeeds against the restored DC, `ldapsearch` returns the expected
users **with their group memberships**, a GPO from SYSVOL is present and readable, and the
domain SID and `krbtgt` match so joined machines would still authenticate. Time it: **RTO is
part of the result**, not a footnote.

What a naive test misses — any one for full marks:
- **SYSVOL was never in the backup**, so LDAP looks perfect and every GPO is gone.
- **Secrets/`krbtgt` not restored**, so users appear correct while every domain-joined
  machine's trust is broken.
- **Nobody measured the restore duration**, so the documented RTO is fiction.
- **Only the one person who wrote it can perform it**, so the procedure has never actually
  been validated.
- Confirming the backup job **exited zero** and calling that verification — which is
  precisely the "hope" the lab is warning about.

---

## Section 5 — Troubleshooting narrative (10)

### D-E4 — model answer

**1. What Bob's successful login already proves (3).** A great deal, and enumerating it is
the skill:
- **DNS works** — he located a DC via SRV records, or he could not have started.
- **The KDC is reachable and issuing tickets** — he has a TGT.
- **His account is valid, enabled, and not locked**, and **his password is correct**.
- **Time skew is within tolerance** — otherwise `kinit` would have failed outright.
- **The workstation's domain join / sssd is healthy.**
- He can reach the file server and **enumerate the share**, so SMB connectivity works and
  the share-level ACL permits at least traversal.

Everything up to *"which groups does this ticket claim he is in"* is eliminated on the
evidence already in the ticket.

*3 for a genuine enumeration with the eliminations stated. A candidate who says "so
authentication works" and stops gets 1.*

**2. Leading hypothesis, as a mechanism (2).** **Bob's Kerberos ticket carries a stale
group list.** Group membership is stamped into the ticket's **PAC at issuance**; adding him
to Finance yesterday does not retroactively rewrite tickets he already holds, and his
session has simply been renewing the same TGT. The file server authorises from **the
ticket**, not by querying AD at access time — so it is enforcing yesterday's membership.

**3. Two commands (2).**
- On Bob's session: **`klist`** — shows the cached TGT and service tickets **with their
  issue times**. A TGT that predates the group change is the confirmation.
- On `dc1`: **`samba-tool group listmembers Finance`** (or `wbinfo -r bob` / `id bob`) —
  proves AD itself *does* contain the new membership. This separates "the change never
  applied" from "the change applied and the ticket is stale", which are different faults
  with the same symptom.

**4. Why Alice is unaffected (1).** Her ticket was issued long after she joined the group,
so her PAC has always contained Finance. Her working access also proves — for free — that
**the share-level and filesystem ACLs for the Finance group are correct**. The permissions
are not the fault, and the ticket told you so without your running a single command.

**5. The fix (1).** **Refresh the credential**: `kdestroy && kinit`, or log out and back in
(a full logoff/logon on Windows). It is **not** a permissions change because the permissions
are already correct — Alice is the proof. "Fixing" this by editing the ACL would grant
access more broadly than intended, leave the real mechanism untouched, and produce the same
confusion the next time somebody changes a group.

**6. Alternative hypothesis and the distinguishing check (1).** If a fresh ticket does not
resolve it: the **filesystem POSIX/ACL layer on `finance` grants a different group** than the
share definition does, **or** Bob was added to a group that does not appear in the token at
all — a **distribution group** rather than a security group, or an unresolved nested group.

**The single distinguishing check:** after a fresh `kinit`, run **`id bob` on the file
server**. If Finance now appears in his token and access still fails, the fault is the
filesystem ACL or the group type. If Finance still does not appear, the group is the wrong
kind or the nesting is not being resolved. If access simply works, it was the stale PAC all
along.

---

## Remediation table

| Question | Topic | Lab |
|---|---|---|
| D1, D6, D-E4 | Kerberos tickets, the PAC, share permissions | `01-active-directory`, `04-domain-join`, `07-file-shares` |
| D2, D-E1 | Clock skew, chrony, NTP hierarchy | `02-ntp-time-services` |
| D3, D-E2, D-C1 | PKI chain, SAN, LDAPS | `03-certificate-authority` |
| D4, D-C2 | SRV records, conditional forwarding, views | `05-dns-deep-dive`, `01-active-directory` |
| D5, D-C3 | DORA, DDNS, TSIG | `06-dhcp-dynamic-dns` |
| D7 | GPO vs Ansible, drift | `08-group-policy` |
| D8 | SPF, DKIM, DMARC | `09-email-gateway` |
| D9 | OIDC, tokens, MFA | `10-sso-federation`, `11-web-proxy` |
| D10, D-E3 | RADIUS methods, clients.conf | `12-radius` |
| D-D1 | Dependency order, expiry blast radius | `16-capstone`, `13-monitoring` |
| D-D2 | Backup design and restore testing | `15-backup-recovery` |
