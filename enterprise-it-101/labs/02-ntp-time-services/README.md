# Lab 02 — NTP & Time Services

**Duration:** 1.5–2 hours

Kerberos — the authentication half of Active Directory you built in Lab 01 — trusts timestamps to stop replay attacks, and it only tolerates **5 minutes** of clock skew between a client and the KDC. That makes time synchronisation a hard dependency of the entire domain, not a nice-to-have. In this lab you stand up a small NTP hierarchy with `chrony`, point the domain controller and workstation at it, and then prove — by deliberately skewing a client's clock — that a host with a perfectly valid password and a perfectly valid ticket still gets locked out the moment its clock drifts too far.

## Topology

```
┌────────────────────────────────────────────────────────────────────┐
│                      lab-corp  10.100.0.0/16                       │
│                                                                    │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐     │
│   │     ntp1     │◀─────│     dc1      │      │   admin-ws   │     │
│   │ chrony NTP   │      │  Samba AD DC │      │ Workstation  │     │
│   │ 10.100.1.20  │◀──────────────────────────│ 10.100.10.10 │      │
│   │ stratum 10   │      │ 10.100.1.10  │      │              │     │
│   │  (serves     │      │ chrony client│      │ chrony client│     │
│   │   the lab)   │      │  stratum 11  │      │  stratum 11  │     │
│   └──────────────┘      └──────────────┘      └──────────────┘     │
│         ▲  serves time (NTP/123) to the lab; clients sync to it    │
└────────────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `dc1` | `samba-ad:local` | `10.100.1.10` | Samba AD DC (auto-provisioned) + chrony client |
| `admin-ws` | `workstation:local` | `10.100.10.10` | Admin workstation + chrony client |
| `ntp1` | `workstation:local` | `10.100.1.20` | Lab NTP server (chrony) |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective** and **hints** — your job is to figure out the commands. Then:

- **Predict before you run.** Each task asks you to commit to an answer first. This is the single highest-value habit in the whole lab — guessing wrong and finding out why is how the knowledge sticks.
- **Reveal the solution only after you've tried.** Commands are hidden behind `Solution` toggles. Use `chronyc help`, `man chrony.conf`, and `--help` first.
- **Observe, don't just verify.** The `Check your work` toggles tell you what to look for *and why it matters* — read them even when your command worked.

!!! warning "Containers share one clock — this lab simulates skew with `faketime`"
    Every container on your machine shares the **host kernel clock**. You cannot
    `date -s` one container into the future without moving the host's clock (and
    `date -s` fails outright without `CAP_SYS_TIME`). So chrony here runs with
    `-x` (it reports sync state but never steps the shared clock), and the
    clock-skew demonstrations use **`faketime`**, which fakes the clock for a
    *single process*. On real hardware these skews are genuine wall-clock drift;
    the Kerberos behaviour you observe is identical either way.

## Prerequisites

- **Lab 01 concepts** (LDAP / Kerberos / DNS, `kinit`, `klist`). You do **not** need a running Lab 01 — `dc1` here auto-provisions the `lab.corp` domain and seeds the Lab 01 users (`alice`, `bob`, `charlie`) and groups for you.
- The custom images built (the same ones Lab 01 uses):

```bash
cd enterprise-it-101
docker build -t samba-ad:local   images/samba-ad/
docker build -t workstation:local images/workstation/
```

## Deploy

Run from the `enterprise-it-101/` directory. The foundation network lives in `base/docker-compose.yml`; this lab layers on top of it:

```bash
cd enterprise-it-101
docker compose -f base/docker-compose.yml \
               -f labs/02-ntp-time-services/docker-compose.override.yml up -d
```

`dc1` takes ~10–20 s to provision and seed the domain on first boot. Watch it with `docker logs -f dc1` until you see `Provision + seed complete`.

## Destroy

```bash
docker compose -f base/docker-compose.yml \
               -f labs/02-ntp-time-services/docker-compose.override.yml down -v
```

---

## What is pre-built

- The `lab.corp` domain, **auto-provisioned** on `dc1` (no manual `samba-tool domain provision`), seeded with the Lab 01 OUs, users, and groups.
- `chrony` installed on all three nodes.
- Client configs for `dc1` and `admin-ws` (they already point at `ntp1`).
- A **deliberately broken** server config on `ntp1` for you to diagnose and fix.

## What you configure

You make `ntp1` a usable time source, point the domain at it, verify the hierarchy, and then prove the Kerberos 5-minute skew rule from the client's seat. By the end you'll know why `chronyc sources` is the *first* command to run when authentication mysteriously breaks across a whole domain at once.

---

## Task 1 — Confirm the foundation came up

**Objective:** Verify the auto-provisioned domain is healthy before you change anything, so that when something breaks later you know *you* broke it.

??? question "Predict first"
    Lab 01 had you run `provision.sh` by hand. This lab's `dc1` provisioned itself. Where did the users `alice`/`bob`/`charlie` come from, and what command proves they exist *without* a network round-trip from the workstation?

??? note "Hints"
    - On `dc1`, `samba-tool user list` and `samba-tool group listmembers <group>` read the local directory.
    - From `admin-ws`, a `kinit` proves Kerberos end-to-end.

??? note "Solution"
    ```bash
    # On the DC: the seeded foundation
    docker exec dc1 samba-tool user list
    docker exec dc1 samba-tool group listmembers engineering

    # From the workstation: Kerberos works end-to-end
    docker exec -it admin-ws kinit alice@LAB.CORP    # password: P@ssw0rd1
    docker exec admin-ws klist | grep krbtgt
    ```

??? success "Check your work"
    `user list` shows `Administrator`, `krbtgt`, `Guest`, `alice`, `bob`, `charlie`; `engineering` lists `alice`. `kinit` succeeds and `klist` shows a `krbtgt/LAB.CORP` TGT. This is exactly the Lab 01 end state — the image's entrypoint ran the same provision + seed steps so Labs 02+ start from a consistent foundation. **Everything works right now. Remember that.**

---

## Task 2 — Make `ntp1` a usable time source

**Objective:** `ntp1` is running but refuses to serve time. Diagnose *why* from `chronyc` output, then fix its config so it becomes a synchronised stratum source for the lab.

The lab config for `ntp1` is at `/etc/chrony/chrony.conf` inside the container (copied from the read-only `lab-ntp1.conf` at startup, so editing it doesn't touch the repo).

??? question "Predict first"
    The config lists exactly one upstream: `server 192.0.2.10`. `192.0.2.0/24` is `TEST-NET-1` (RFC 5737) — a documentation range that routes nowhere. Before you start chrony: will `ntp1` serve time to clients anyway using its own clock, or will it refuse? Why would an NTP server refuse to answer at all?

??? note "Hints"
    - Start the daemon: `chronyd -x -f /etc/chrony/chrony.conf` (the `-x` is required in this lab — see the warning up top).
    - `chronyc sources` shows each source and a reachability column; `chronyc tracking` shows whether *this* host considers itself synchronised.
    - A server that is itself **not synchronised** won't hand out time. Read the bottom of `chrony.conf` — the fix is written there, commented out. `man chrony.conf` explains the `local` directive.
    - After editing, restart: `chronyc shutdown` then run `chronyd -x -f …` again.

??? note "Solution"
    ```bash
    docker exec -it ntp1 bash

    chronyd -x -f /etc/chrony/chrony.conf
    chronyc sources      # 192.0.2.10 shows '^?' (unreachable), Reach 0
    chronyc tracking     # "Leap status : Not synchronised", Stratum 0

    # Fix: let ntp1 serve its own clock when no upstream is reachable.
    sed -i 's/^# local stratum 10/local stratum 10/' /etc/chrony/chrony.conf
    chronyc shutdown
    chronyd -x -f /etc/chrony/chrony.conf

    chronyc tracking     # now "Leap status : Normal", Stratum 10
    ```

??? success "Check your work"
    Before the fix, `chronyc tracking` reports **`Leap status : Not synchronised`** and `Stratum 0`, and `chronyc sources` shows `192.0.2.10` with `^?` and `Reach 0` — chrony has no valid time, so it will not serve clients. After enabling `local stratum 10`, tracking shows **`Leap status : Normal`** and **`Stratum 10`** with a `Reference ID` of `7F7F0101` (that's `127.127.1.1`, the local reference clock).

    The lesson: **an NTP server only serves time it trusts.** `local stratum 10` is the standard "island mode" fallback — it lets a server stay authoritative for an isolated network when its upstreams are gone, at a deliberately high (worse) stratum so a real upstream would win if it returned. Your prediction was right if you said it would refuse.

---

## Task 3 — Point the domain at `ntp1` and verify the hierarchy

**Objective:** Start the chrony client on `dc1` and `admin-ws`, confirm both lock onto `ntp1`, and read the stratum numbers to see the hierarchy you just built.

Both clients already have the correct config (`server 10.100.1.20 iburst`). You just need to start them and read the output.

??? question "Predict first"
    `ntp1` synchronised at **stratum 10**. When `dc1` and `admin-ws` lock onto it, what stratum will *they* report — 10, or something else? What does the stratum number actually count?

??? note "Hints"
    - On `dc1`, chrony is a supervised service: `supervisorctl start chrony`.
    - On `admin-ws` (no supervisor): `chronyd -x -f /etc/chrony/chrony.conf`.
    - Give `iburst` a few seconds, then `chronyc sources` and `chronyc tracking`.
    - In `chronyc sources`, the `^*` marker means "this is the source I'm synced to."

??? note "Solution"
    ```bash
    # dc1
    docker exec dc1 supervisorctl start chrony
    docker exec dc1 chronyc sources       # ntp1 should appear with '^*'
    docker exec dc1 chronyc tracking      # Stratum 11, Leap status Normal

    # admin-ws
    docker exec admin-ws chronyd -x -f /etc/chrony/chrony.conf
    sleep 8
    docker exec admin-ws chronyc sources
    docker exec admin-ws chronyc tracking
    ```

??? success "Check your work"
    Both clients show `ntp1` with **`^*`** in `chronyc sources` and **`Stratum 11`** in `chronyc tracking`, with `Reference ID` resolving to `ntp1`. Your prediction: stratum is **one more than your source** — it counts hops away from the reference clock. `ntp1` is stratum 10 (one hop from its local refclock at 9), so its clients are stratum 11. This is the entire structure of NTP: stratum 0 = a real clock (atomic/GPS), stratum 1 = directly attached, and every layer below adds one. Lower stratum = closer to truth = more trusted.

    If `admin-ws` still shows `Not synchronised`, wait a few more seconds — `iburst` needs a couple of exchanges before it commits to a source (the `Reach` column climbs `1 → 3 → 7 → 17 …` in octal as samples arrive).

---

## Task 4 — Make Kerberos's 5-minute rule visible

**Objective:** With time correct everywhere, establish the baseline, then use `faketime` to *reveal* the dependency you can't normally see: that Kerberos silently rejects authentication once a clock drifts past tolerance.

This is the heart of the lab. Don't just run the commands — read what passes and what fails, and notice **which step** fails.

??? question "Predict first"
    You'll `kinit` (get a TGT) normally, then run `kvno host/dc1.lab.corp` — once with a clock faked **+10 minutes**, once normally. Predict: does the **`kinit`** fail, the **`kvno`** fail, both, or neither? (Gotcha: think about whether the client can *discover* it's out of sync before it sends its first authenticator.)

??? note "Hints"
    - `faketime '<offset>' <command>` runs one command with a shifted clock, e.g. `faketime '+10 minutes' kvno host/dc1.lab.corp@LAB.CORP`.
    - `kvno <service>/<host>@REALM` forces the client to request a *service ticket* (a TGS exchange) — that builds a fresh authenticator stamped with the current (faked) time.
    - A GSSAPI bind exercises the same path: `faketime '+10 minutes' ldapsearch -Y GSSAPI -H ldap://dc1.lab.corp -b "DC=lab,DC=corp" "(sAMAccountName=alice)" dn`.
    - **Always `kdestroy; kinit` before each `faketime kvno` test.** If a service ticket for `host/dc1.lab.corp` is already cached, `kvno` returns it from cache without contacting the KDC — the skew check never runs and you'll falsely conclude the time is fine. A fresh `kinit` clears the TGS cache so `kvno` is forced to request a new ticket.

??? note "Solution"
    ```bash
    docker exec -it admin-ws bash

    # Baseline: correct time — everything works.
    kdestroy; kinit alice@LAB.CORP                     # P@ssw0rd1
    kvno host/dc1.lab.corp@LAB.CORP                    # -> kvno = N (success)

    # Always destroy and re-init before a faketime test — a cached service
    # ticket will be returned without a KDC round-trip, masking the skew failure.
    kdestroy; kinit alice@LAB.CORP

    # Now skew only the service request by 10 minutes.
    faketime '+10 minutes' kvno host/dc1.lab.corp@LAB.CORP

    # Same failure via a real LDAP operation:
    faketime '+10 minutes' ldapsearch -Y GSSAPI -H ldap://dc1.lab.corp \
        -b "DC=lab,DC=corp" "(sAMAccountName=alice)" dn
    ```

??? success "Check your work"
    The baseline `kvno` returns `kvno = 1`. The **+10-minute** `kvno` fails with:

    ```
    kvno: Clock skew too great while getting credentials for host/dc1.lab.corp@LAB.CORP
    ```

    and the GSSAPI bind fails with `GSSAPI Error: … (Clock skew too great)`.

    The surprising part — and the answer to the prediction — is *where* it fails. A skewed **`kinit` often still succeeds**, because MIT Kerberos auto-corrects: during pre-authentication the KDC's reply reveals the server's time, the client computes the offset, and re-sends a correctly-stamped request. But that learned offset lives in the ccache; a brand-new authenticator built under `faketime` (the `kvno`/GSSAPI path) carries the faked timestamp, and the KDC checks it against *its* real clock. **So the login looks fine and then resource access breaks** — the exact symptom mismatch from Lab 01's challenge question 2. Time problems rarely say "your clock is wrong"; they say "credentials" and "skew."

---

## Task 5 — Break it: find the tolerance, diagnose, repair

**Objective (required Break-It):** Pin down the *exact* skew Kerberos tolerates, experience the failure as a symptom you'd see in production, then "repair" the host and confirm recovery — closing the loop on why Tasks 2–3 are mandatory, not optional.

??? question "Predict first"
    Kerberos's default tolerance is **±5 minutes (300 s)**. Predict the boundary: at `+5 minutes` exactly, does the service request pass or fail? At `+6 minutes`? Write down both before testing.

??? note "Hints"
    - Each test needs a **fresh** service ticket, or you'll just read a cached one. Reset with `kdestroy; kinit alice@LAB.CORP` before each `kvno`.
    - Sweep a few offsets: `+4 minutes`, `+5 minutes`, `+6 minutes`, `+10 minutes`.
    - Negative skew counts too — try `'-6 minutes'`.

??? note "Solution"
    ```bash
    for off in '+4 minutes' '+5 minutes' '+6 minutes' '+10 minutes'; do
      kdestroy 2>/dev/null; kinit alice@LAB.CORP >/dev/null   # P@ssw0rd1
      echo -n "$off -> "
      faketime "$off" kvno host/dc1.lab.corp@LAB.CORP 2>&1 | tail -1
    done
    ```

    **Repair** — there's nothing to "un-fake"; the point is that a host whose *real* clock is within tolerance just works. Prove it by running the same request with no `faketime`, and confirm chrony is keeping you in tolerance:

    ```bash
    kdestroy; kinit alice@LAB.CORP
    kvno host/dc1.lab.corp@LAB.CORP        # success — real clock, in tolerance
    chronyc tracking | grep -E 'Leap|System time'
    ```

??? success "Check your work"
    The sweep shows a hard cliff:

    ```
    +4 minutes  -> host/dc1.lab.corp@LAB.CORP: kvno = 1
    +5 minutes  -> host/dc1.lab.corp@LAB.CORP: kvno = 1
    +6 minutes  -> kvno: Clock skew too great while getting credentials …
    +10 minutes -> kvno: Clock skew too great while getting credentials …
    ```

    `+5` passes (the boundary is inclusive), `+6` fails — confirming the 5-minute window, symmetric for negative skew. The "repair" is conceptual but important: **the fix for a skew outage is not in Kerberos, it's in NTP.** A host kept synced by `ntp1` can never drift into this failure on its own. That is why, in a real AD domain, every member syncs to the DC hierarchy and the DCs sync to an authoritative source — and why `chronyc sources` / `chronyc tracking` is the first thing you check when "nobody can log in" reports start at, say, exactly the moment a VM was restored from a stale snapshot.

---

## Verification Checklist

Run these to confirm the lab's outcomes before moving on:

```bash
# NTP server is authoritative for the lab
docker exec ntp1 chronyc tracking | grep -E 'Stratum|Leap'        # Stratum 10, Normal

# Both clients are synced to ntp1
docker exec dc1       chronyc tracking | grep -E 'Reference ID|Leap'   # -> ntp1, Normal
docker exec admin-ws  chronyc tracking | grep -E 'Reference ID|Leap'   # -> ntp1, Normal

# Kerberos works at correct time …
docker exec -it admin-ws bash -c 'kdestroy; kinit alice@LAB.CORP && kvno host/dc1.lab.corp@LAB.CORP'

# … and fails past the 5-minute window
docker exec admin-ws bash -c 'kdestroy; kinit alice@LAB.CORP >/dev/null; \
  faketime "+6 minutes" kvno host/dc1.lab.corp@LAB.CORP'   # Clock skew too great
```

!!! note "`chronyc` shows the source by reverse name"
    `chronyc sources` may print `ntp1` as `ntp1.eit101-lab02_lab-corp` — that's
    Docker's embedded DNS reverse-resolving `10.100.1.20`. It's the same host.

---

## Challenge Questions

No solutions provided — reason it through.

1. **First command on a domain-wide outage.** At 09:00 every user in the domain suddenly can't access file shares, though some say they "logged in fine an hour ago." You suspect time. Which *one* command, on which host, would most quickly confirm or rule out a skew problem — and what specific field in its output decides it?

2. **Why login survives but access dies.** Explain, in terms of the AS exchange vs. the TGS exchange, why a host with a 10-minute skew can sometimes still `kinit` successfully but then fails every service request. What does this tell you about trusting "the user can log in, so auth is fine" as a diagnosis?

3. **The DC is the clock too.** In a real AD domain the DC holding the PDC-emulator role is the time root, and members sync to the DC they authenticate against. What dangerous feedback loop could occur if you instead pointed your *only* DC at an external NTP server that suddenly jumped its clock forward by an hour? Walk through what happens to every member.

4. **Stratum design.** You add a second NTP server `ntp2` for redundancy. Should it be a *peer* of `ntp1`, a *client* of `ntp1`, or an independent server at the same stratum pointing at the same upstream? Argue for one, and say what failure mode each of the other two would introduce.

5. **Design extension (previews Lab 04).** When `ws1` joins the domain in Lab 04, nothing in `realm join` configures NTP explicitly. Given what you saw here, what must already be true about `ws1`'s clock for the join's Kerberos steps to succeed, and where would a freshly-imaged machine most plausibly get a wrong clock?

---

## Key Concepts

**Time is a hard dependency of Kerberos:**

| Fact | Consequence |
|------|-------------|
| Authenticators carry a timestamp | Replays are rejected by time, so clocks must agree |
| Default tolerance is ±5 min (300 s) | Drift past 5 min = `Clock skew too great` |
| The KDC checks against *its* clock | A skewed client fails even with the right password/ticket |
| MIT clients auto-correct during AS preauth | `kinit` can succeed while service access fails — symptom mismatch |

**NTP is hierarchical:**

- **Stratum** counts hops from a reference clock: stratum 0 = a real clock, stratum 1 = directly attached, each layer adds one. Lower = more trustworthy.
- A server **only serves time it trusts** — an unsynchronised server (no reachable source, no `local`) refuses clients outright.
- `local stratum N` is "island mode": stay authoritative for an isolated network at a deliberately-bad stratum so a real upstream wins if it returns.

**Slewing vs. stepping:**

NTP clients correct clock drift in two ways:

- **Slew** — gradually speed up or slow down the clock (typically ≤500 ppm, ~1.8 s/hour) until it converges on the correct time. This is the default for small corrections and is safe because time never jumps backward.
- **Step** — instantly set the clock to the correct value. Fast, but dangerous: a backward step can break anything that depends on monotonic time (log timestamps, certificate validity, Kerberos tickets). Most NTP clients (including chrony) only allow stepping at startup (`makestep 1.0 3` = "step if offset > 1 s, but only for the first 3 updates"), then switch to slew-only.

Why this matters: a 1-hour clock jump on an NTP server cannot be corrected by slewing before Kerberos tickets expire (~10 hours). Slewing 1 hour at 500 ppm takes ~80 hours. This is why sudden large jumps — from a misbehaving upstream, a VM restored from a stale snapshot, or a manual `date -s` typo — cause domain-wide outages that don't self-heal.

**NTP redundancy — peer vs. client vs. independent:**

When adding a second NTP server (`ntp2`) for redundancy, the topology matters:

- **Independent servers at the same stratum** (recommended) — both point at the same upstream (or different upstreams for more resilience). If one fails, clients fail over to the other. Each has an independent reference, so they can detect each other drifting.
- **Peer mode** — two servers treat each other as equals and can sync from each other if their upstream disappears. The danger: if *both* lose their upstream simultaneously, they agree with each other and drift together confidently, with no external reference to detect the error. Consensus ≠ correctness.
- **`ntp2` as a client of `ntp1`** — `ntp2` just relays `ntp1`'s time. If `ntp1` goes down, `ntp2` loses its source too. Adds a hop but no resilience.

**The two commands that matter:**

- `chronyc sources` — *who* am I getting time from, and is it reachable? (`^*` = synced source, `^?` = unreachable.)
- `chronyc tracking` — am *I* synchronised, at what stratum, with what offset? (`Leap status : Normal` vs `Not synchronised`.)

When authentication breaks across a whole domain at once, suspect time before you suspect AD.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `chronyd` exits immediately / "Could not... adjtimex" | Container can't control the clock | Always start it with `-x` in this lab |
| "Another chronyd may already be running (pid=…)" | A chronyd is already up in that container | `chronyc shutdown` (or `pkill chronyd`), then start it once |
| `chronyc tracking` shows `Not synchronised` on `ntp1` | Only source is unreachable, no `local` | Enable `local stratum 10` (Task 2) |
| Client source shows `^?` and never `^*` | Not enough samples yet, or `ntp1` unsynced | Wait for `iburst`; confirm `ntp1` tracking is `Normal` |
| `kvno`/`ldapsearch` → `Clock skew too great` | Clock skew > 5 min (here, `faketime`) | Use real/in-tolerance time; in production, fix NTP |
| `kinit` succeeds but service access fails | Client auto-corrected AS, but skewed TGS authenticator | The clock is still wrong — check `chronyc tracking` |
| `samba-tool user list` empty / `kinit` fails right after deploy | `dc1` still provisioning | `docker logs -f dc1` until `Provision + seed complete` |

---

## What's Next

- **Lab 03 (Certificate Authority & PKI)** — you'll stand up an internal CA and finally use port 636 (LDAPS), which has been listening since Lab 01 with no usable certificate. Issuing and trusting certs has its own time dependency: a cert is only valid *between* its `notBefore` and `notAfter` — another place where a wrong clock breaks everything silently.
- **Lab 04 (Domain Join)** — `ws1`/`ws2` will join `lab.corp` using the SRV discovery from Lab 01; their join only works because their clocks are within the 5-minute window you measured here.
- **Lab 16 (Capstone)** — one of the break/fix scenarios skews `dc1`'s clock and asks you to diagnose a domain-wide outage from the symptoms. You just built the mental model for it.
