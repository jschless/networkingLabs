# Exam D — Enterprise IT 101

**Time:** 1.5 hours · **Total:** 100 points · **Closed book, no CLI**

Covers `enterprise-it-101/labs/01`–`16`: Active Directory, time, PKI, domain join, DNS,
DHCP, file shares, config management, mail, SSO, proxy, RADIUS, monitoring, SIEM, and
backup.

The organising idea of this curriculum is that **DNS, Kerberos, LDAP, and time are not
separate services but one chain of dependencies**, and a break in one link surfaces as a
symptom three links away. Most of this exam is about that chain.

---

## Section 1 — Concepts & mechanisms (30 points)

Ten questions, 3 points each.

**D1.** Active Directory speaks LDAP, Kerberos, and (still) NTLM. State what each one is
*for* in AD. Then walk the Kerberos exchange from a cold login to opening a file share:
name the three request/response pairs, what the client gets from each, and the one thing
the file server never receives.

**D2.** Kerberos tolerates **five minutes** of clock skew. (a) What attack does that limit
exist to prevent, and what in the protocol makes the timestamp load-bearing? (b) Describe
the user-visible symptom of a workstation that has drifted past the limit — be specific
about what still works and what does not. (c) Why is the symptom so often misdiagnosed as a
password problem?

**D3.** Lab 03 stands up a root CA and an intermediate. (a) Why issue from an intermediate
rather than the root — what does that buy you operationally? (b) What exactly must
`admin-ws` possess for `ldaps://dc1.lab.corp` to validate, and what must the DC's
certificate contain for the hostname check to pass? (c) In Lab 01 a cleartext simple bind
was rejected and you worked around it with GSSAPI. Explain what changed in Lab 03 that made
the simple bind acceptable.

**D4.** DNS in this domain. (a) Why does an AD domain depend on **SRV records**
specifically, and what does a client look up before it can authenticate at all?
(b) Define conditional forwarding and say why `dns1` conditionally forwards `lab.corp` to
`dc1` rather than being authoritative for it. (c) Define split-horizon and give the
mechanism BIND uses to implement it.

**D5.** DHCP and dynamic DNS. (a) Name the four DORA messages and say which are broadcast
and which unicast. (b) Explain what DDNS adds and which component performs the update in
the Lab 06 design. (c) Why is the update **TSIG-authenticated**, and what could an attacker
do to the domain if it were not?

**D6.** File shares. (a) Describe the **two independent permission layers** that both have
to allow an operation before a user can write a file to a Samba share, and say which one
wins when they disagree. (b) What does it mean for a share to be mounted "with Kerberos",
and what does that avoid? (c) A user is added to a group that grants access, and still gets
"Access Denied" until they log out and back in. Explain why.

**D7.** Group Policy and Ansible both appear in Lab 08 as configuration management.
(a) State the delivery model of each — who initiates, and on what schedule. (b) Give one
thing GPO can do that an Ansible playbook is a poor fit for, and one thing Ansible can do
that GPO cannot. (c) Both claim to enforce "desired state". Explain what each actually does
when someone changes a setting by hand.

**D8.** Email authentication. For **SPF**, **DKIM**, and **DMARC**, state what each one
proves, what it does **not** prove, and which of the two "from" addresses it is checked
against. Then explain why DKIM survives forwarding and SPF usually does not.

**D9.** SSO with Keycloak. (a) Walk the OIDC **Authorization Code flow** for a user opening
the sample app: who redirects whom, and where the credential is actually entered.
(b) Distinguish the **ID token** from the **access token** — different audiences, different
purposes. (c) The lab says the app never sees the password and Keycloak never stores one.
Explain both halves. (d) When TOTP MFA is enabled, which component enforces it, and why the
app needs no change.

**D10.** RADIUS against AD (Lab 12). Trace all three authentication methods from the NAS to
AD: **PAP**, **PEAP/MSCHAPv2**, and **EAP-TLS** — for each, say what the RADIUS server does
with the credential and which AD interface it uses. Then explain why a **shared-secret
mismatch** between the NAS and the RADIUS server fails *silently*, and what that looks like
from each end.

---

## Section 2 — Evidence reading (20 points)

### D-E1 (7 points)

On `admin-ws`:

```text
admin-ws:~$ kinit alice
Password for alice@LAB.CORP:
kinit: Clock skew too great while getting initial credentials

admin-ws:~$ chronyc tracking
Reference ID    : 00000000 ()
Stratum         : 0
Ref time (UTC)  : Thu Jan  1 00:00:00 1970
System time     : 0.000000000 seconds fast of NTP time
Last offset     : +0.000000000 seconds
Leap status     : Not synchronised

admin-ws:~$ chronyc sources
MS Name/IP address    Stratum Poll Reach LastRx Last sample
========================================================================
^? ntp1.lab.corp            0    6     0      -     +0ns[   +0ns] +/-    0ns
```

(a) Read the three outputs together and state precisely what has failed. Note what the
`Reach` column and the `^?` marker are telling you. (3 pts)
(b) The user insists the password is correct. Say whether that is consistent with this
output and why. (2 pts)
(c) Name two candidate root causes for the state shown, and the check that separates them.
(2 pts)

### D-E2 (7 points)

On `admin-ws`, after the CA is up and the DC has been issued a certificate:

```text
admin-ws:~$ ldapsearch -H ldaps://dc1.lab.corp -D "alice@lab.corp" -W -b "dc=lab,dc=corp" "(cn=alice)"
ldap_sasl_bind(SIMPLE): Can't contact LDAP server (-1)
        additional info: error:0A000086:SSL routines::certificate verify failed
                         (unable to get local issuer certificate)

admin-ws:~$ ldapsearch -H ldaps://10.100.1.10 -D "alice@lab.corp" -W -b "dc=lab,dc=corp" "(cn=alice)"
ldap_sasl_bind(SIMPLE): Can't contact LDAP server (-1)
        additional info: error:0A000086:SSL routines::certificate verify failed
                         (unable to get local issuer certificate)
```

(a) The DC is listening, the certificate exists, and the CA issued it. Name the failure
precisely and say which end is at fault. (3 pts)
(b) State the fix, and the command from the lab's toolset that performs it. (2 pts)
(c) Suppose the trust were correct and the error changed to *"hostname does not match
certificate"* on the first command but the second still failed differently. What would that
tell you about the certificate, and what field would you inspect? (2 pts)

### D-E3 (6 points)

On `nas1`, testing RADIUS:

```text
nas1:~$ radtest alice 'Passw0rd!' 10.100.20.10 0 testing123
Sent Access-Request Id 141 from 0.0.0.0:35218 to 10.100.20.10:1812 length 76
Sent Access-Request Id 141 from 0.0.0.0:35218 to 10.100.20.10:1812 length 76
Sent Access-Request Id 141 from 0.0.0.0:35218 to 10.100.20.10:1812 length 76
(0) No reply from server for ID 141
```

Meanwhile, on `radius1` running in debug mode, the log shows only:

```text
Ready to process requests
Ignoring request to auth address * port 1812 bound to server default from unknown client 10.100.20.11 port 35218
```

(a) Name the fault. (2 pts)
(b) Explain why the client sees a *timeout* rather than an Access-Reject, and why that
distinction is diagnostically valuable. (2 pts)
(c) Which file would you correct, what would you add, and what must you do afterwards for
it to take effect in this lab? (2 pts)

---

## Section 3 — Implementation on paper (25 points)

### D-C1 (9 points) — Issue a DC certificate and enable LDAPS

Write the **ordered procedure** to take `dc1` from "no certificate, LDAPS unusable" to "a
simple bind over `ldaps://dc1.lab.corp` succeeds from `admin-ws`". For each step give the
action, the host it runs on, and the `step` (or equivalent) command family. You must
address:

- establishing trust in the CA on both `dc1` and `admin-ws`
- what identity the certificate must be issued **for**, and the field that makes hostname
  validation pass
- where the certificate and key go, and what must be restarted
- the verification command, and a second verification that proves the *chain* rather than
  just the connection

State also what the certificate's validity window means for this lab, given Lab 02.

### D-C2 (8 points) — BIND9 split-horizon and conditional forwarding

Write the `named.conf` structure for `dns1` that:

- serves **internal** clients (`10.100.0.0/16`) an internal answer for `www.lab.corp`
- serves **external** clients (everything else, including `ext-client`) a different answer
  for the same name
- conditionally forwards the rest of `lab.corp` to `dc1` at `10.100.1.10`
- recurses to the internet for everything else, but **only for internal clients**

Show the views with their `match-clients`, the zone stanzas, the forward zone, and the
recursion controls. Note the one ordering rule about views that will bite you if you get it
wrong.

### D-C3 (8 points) — Kea DHCP with TSIG-authenticated DDNS

Write the Kea configuration fragments for subnet `10.100.10.0/24` that:

- offers a pool of `10.100.10.50`–`10.100.10.99`
- hands out gateway, DNS (`10.100.1.40`), NTP (`10.100.1.20`), and domain name `lab.corp`
- performs forward and reverse DDNS updates into the `dhcp.lab.corp` zone
- authenticates those updates with a TSIG key

Show the Kea side **and** the matching BIND side (the `key` statement and the zone's
`allow-update`). State which component actually sends the DNS UPDATE.

---

## Section 4 — Design & trade-offs (15 points)

### D-D1 (8 points)

The whole `lab.corp` estate has lost power and is coming back up cold.

(a) Give the order in which you bring services back, and for each, the dependency that
forces its position. (4 pts)
(b) The CA's **intermediate** certificate expired overnight while everything was down. List
what breaks, in the order you would notice it, and say which failures will present as
something other than a certificate problem. (3 pts)
(c) One service in this estate can be down for a day without anyone filing a ticket, and
its absence is still an emergency. Name it and justify. (1 pt)

### D-D2 (7 points)

Design the backup for the two things Lab 15 calls unforgivable to lose: the **AD database**
and the **CA private key**.

(a) For each, state what you back up (be specific — it is not "the container"), and whether
the copy needs to be **application-consistent** or whether crash-consistent will do.
Justify. (3 pts)
(b) The CA key and the backup repository are both encrypted. Explain the bootstrapping
problem that creates and how you would solve it. (2 pts)
(c) The lab's line is "a backup you have never restored is not a backup, it's a hope."
Describe a restore test for the AD database that would actually prove something, and name
one thing a naive test would miss. (2 pts)

---

## Section 5 — Troubleshooting narrative (10 points)

### D-E4

**Ticket:** *"Bob can log in to his workstation normally. He can browse the file server and
see the share. When he opens the `finance` folder he gets Access Denied. He was added to the
Finance group yesterday. Alice, who has been in the group for months, has no problem."*

Structure your answer:

1. **What Bob's successful login already proves** — enumerate the parts of the chain you can
   eliminate on that evidence alone. (3 pts)
2. **The leading hypothesis**, stated as a mechanism. (2 pts)
3. **Two commands** that would confirm it, with what each shows. (2 pts)
4. **Why Alice is unaffected**, and what her working access tells you about the share's
   configuration. (1 pt)
5. **The fix**, and why it is not a permissions change. (1 pt)
6. **The alternative hypothesis** you would fall back to if the first is disproved, and the
   single check that distinguishes the two. (1 pt)

---

*End of Exam D. Key: [`answer-keys/exam-d-key.md`](answer-keys/exam-d-key.md).*
