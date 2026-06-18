# Lab 14 — SIEM & Security Logging

**Duration: 2.5–3 hours**

Lab 13 taught you to notice when a service *stops*. This lab teaches you to
notice when someone is *attacking* it. You stand up a **Wazuh** manager — the
open-source SIEM (Security Information and Event Management) platform — and turn
the hosts you built in earlier labs into sensors that ship their security logs
to it. Then you make the SIEM earn its keep: you watch it catch an SSH
brute-force in real time, teach it to read Active Directory's authentication
audit log, write your own detection rules for failed logins and new-account
creation, and wire up an **active response** that firewalls off an attacker
automatically. By the end you'll have built the thing every security team lives
inside — and felt its sharpest limitation: a SIEM only sees what you remember
to point at it.

## Topology

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                            lab-corp  10.100.0.0/16                             │
│                                                                                │
│   monitored hosts (Wazuh agent installed — you enroll + configure them)        │
│   ┌──────────────┐                      ┌──────────────┐                       │
│   │     dc1      │  Samba AD authn       │   admin-ws   │  sshd + /var/log/    │
│   │  Samba AD    │  audit (JSON) ───┐    │  your seat   │  auth.log ──┐        │
│   │ 10.100.1.10  │                  │    │ 10.100.10.10 │             │        │
│   └──────────────┘                  │    └──────▲───────┘             │        │
│        agent ──────────────┐        │           │ ssh brute force     │        │
│                            ▼        ▼           │                     ▼        │
│                       ┌──────────────────┐      │            ┌──────────────┐  │
│                       │  wazuh-manager   │◄─────agent────────┤   (agent)    │  │
│                       │   10.100.3.30    │      │            └──────────────┘  │
│                       │  rules · decoders│      │                              │
│                       │alerts.json·:55000│      │   ┌──────────────┐           │
│                       │  active response ───────┼──►│   intruder   │ DROP ◄─┐  │
│                       └──────────────────┘      │   │ 10.100.10.66 │        │  │
│                                                 └───┤  (no agent)  ├────────┘  │
│                                                     └──────────────┘           │
└────────────────────────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `wazuh-manager` | `wazuh/wazuh-manager:4.14.5` | `10.100.3.30` | SIEM manager — decoders, rules, alerts, active response, REST API on `:55000` |
| `dc1` | `samba-ad-wazuh:local` | `10.100.1.10` | AD DC with **Samba JSON audit logging** on and the agent **installed but not enrolled** |
| `admin-ws` | `workstation-wazuh:local` | `10.100.10.10` | Your seat; runs `sshd`, agent installed-not-enrolled, `iptables` for active response |
| `intruder` | `workstation-wazuh:local` | `10.100.10.66` | An ordinary corp workstation with **no agent** — you'll misuse it to attack `admin-ws` |

There is deliberately **no Wazuh indexer or dashboard** here. A single-node
OpenSearch indexer plus the dashboard needs roughly 2.5 GB of RAM on top of this
stack, which overruns the memory ceiling of a typical Docker Desktop VM and
makes the lab flaky. Everything this lab teaches lives **manager-side** — you
read alerts straight from `/var/ossec/logs/alerts/alerts.json` and the REST API,
which is exactly how you'd debug rules on a real deployment before trusting the
pretty graphs. The optional dashboard is covered in an appendix at the end.

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective**
and **hints** — your job is to produce the command, config, or rule. Then:

- **Predict before you run.** Commit to an answer first; being wrong and seeing
  why is the point.
- **Reveal the solution only after you've tried.** Full answers are behind
  `Solution` toggles. You edit agent configs in-place (`vi` is in the images)
  and the manager's rule file on `wazuh-manager`.
- **Observe, don't just verify.** The `Check your work` toggles explain the
  mechanism, not just the result.

## Prerequisites

- Concepts from Lab 01 (AD authentication, Kerberos) and a passing familiarity
  with Lab 13 (you read logs/alerts there too). The AD foundation is
  auto-provisioned — you don't need to have run the earlier labs.
- Build the custom images first (skip if already built). The two Wazuh images
  derive from `samba-ad`/`workstation`, so build those too:

```bash
cd enterprise-it-101
./eit.sh build samba-ad workstation samba-ad-wazuh workstation-wazuh
```

Only one EIT101 lab can run at a time (they share the `10.100.0.0/16` subnet) —
`./eit.sh down <other-lab>` first if needed. This lab publishes **no** host
ports; you reach everything via `docker exec`.

## Deploy

```bash
cd enterprise-it-101
./eit.sh up 14          # or the explicit docker compose -f ... form
```

First boot takes 1–2 minutes: `dc1` provisions the domain and `wazuh-manager`
initialises its indexer-less data dir and the REST API. Wait until
`docker exec wazuh-manager /var/ossec/bin/wazuh-control status` shows the
processes running before you start enrolling agents.

## Destroy

```bash
./eit.sh down 14        # add -v to also wipe volumes (fresh manager + domain)
```

The manager's enrollment keys, your custom rules, and alert history live in
named volumes, so a plain `down`/`up` keeps your work. `down -v` resets
everything to a clean slate.

## What is pre-built / what you configure

Pre-built (scaffolding, not the lesson):

- The **Wazuh manager**, fully started, with the REST API up on `:55000`.
- The **agent package installed** on `dc1` and `admin-ws` — but unconfigured:
  its `ossec.conf` still points at a placeholder `MANAGER_IP` and the service
  is stopped. Pointing it at the manager and enrolling it is your job.
- **Samba JSON audit logging** already enabled on `dc1` (it writes every
  authentication and directory change to `/var/log/samba/samba.log`). Shipping
  that log to Wazuh is your job.
- `admin-ws` runs `sshd` (logging to `/var/log/auth.log` via rsyslog) and has a
  weak local account, `svc-backup`, for the attacker to target.
- `intruder` is a bare workstation with `sshpass` — your attack box.

You configure: agent enrollment, every log source, your own detection rules,
the active-response firewall block, and file integrity monitoring. That's the
job.

---

## Task 1 — Deploy and find the moving parts (guided)

**Objective:** Bring the lab up and confirm the asymmetry you'll spend the lab
fixing: the manager is running and listening, but the agents are installed,
stopped, and pointed at nothing.

Run these and read the output:

```bash
# Manager processes (analysisd, remoted, execd, the API...) should be running.
docker exec wazuh-manager /var/ossec/bin/wazuh-control status

# The manager knows about ZERO agents so far (only itself, id 000).
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# On dc1 the agent is installed but unconfigured — note the placeholder.
docker exec dc1 grep -m1 '<address>' /var/ossec/etc/ossec.conf
```

??? success "Check your work"
    `wazuh-control status` lists `wazuh-analysisd`, `wazuh-remoted`,
    `wazuh-execd`, `wazuh-db`, and friends as *running*. `agent_control -l`
    shows only `ID: 000, Name: wazuh-manager (server)` — no real agents yet.
    And dc1's config reads `<address>MANAGER_IP</address>`: a literal,
    never-resolves placeholder. This is the normal state right after you
    `apt install wazuh-agent` on a fleet — the package is there, but every host
    is deaf until you enroll it. The rest of the lab is turning these deaf hosts
    into a sensor grid.

## Task 2 — Enroll the domain controller's agent

**Objective:** Point dc1's agent at the manager, register it, and start it.
Confirm it appears as **Active** on the manager.

Enrollment is two ideas: the agent needs the manager's *address*, and the
manager needs to *trust* the agent (a shared key, obtained once via the
`agent-auth` registration service on port 1515).

??? question "Predict first"
    After the agent registers and starts, will the manager immediately show
    security *alerts* from dc1? Why or why not?

??? note "Hints"
    - Edit `/var/ossec/etc/ossec.conf` on dc1 and replace `MANAGER_IP` with the
      manager's IP (`10.100.3.30`).
    - The registration client is `/var/ossec/bin/agent-auth -m <manager-ip>`.
    - These container images have **no systemd**. Start the agent with
      `/var/ossec/bin/wazuh-control start`, *not* `systemctl`.
    - Verify from the manager with `agent_control -l`.

??? note "Solution"
    ```bash
    docker exec dc1 bash -c '
      sed -i "s|MANAGER_IP|10.100.3.30|" /var/ossec/etc/ossec.conf
      /var/ossec/bin/agent-auth -m 10.100.3.30
      /var/ossec/bin/wazuh-control start
    '
    # Give it ~10s, then from the manager:
    docker exec wazuh-manager /var/ossec/bin/agent_control -l
    ```

??? success "Check your work"
    `agent-auth` prints `Valid key received` and the manager now lists
    `ID: 001, Name: dc1 ... Active`. But you should see **no security alerts**
    from dc1 yet — that was the prediction. Enrolling an agent only opens the
    channel; the agent still only ships the few log sources in its *default*
    config (you'll see exactly which in Task 4), and you haven't pointed it at
    the AD audit log yet. A freshly enrolled agent is connected but nearly
    blind — connectivity is not visibility.

## Task 3 — Enroll your workstation too

**Objective:** Repeat the enrollment for `admin-ws` so the host running `sshd`
is also a sensor. You'll attack this host in Task 4.

??? note "Hints"
    - Identical procedure to Task 2, run inside `admin-ws`.
    - Same manager IP. The agent picks its own name from the hostname.

??? note "Solution"
    ```bash
    docker exec admin-ws bash -c '
      sed -i "s|MANAGER_IP|10.100.3.30|" /var/ossec/etc/ossec.conf
      /var/ossec/bin/agent-auth -m 10.100.3.30
      /var/ossec/bin/wazuh-control start
    '
    docker exec wazuh-manager /var/ossec/bin/agent_control -l
    ```

??? success "Check your work"
    The manager now lists **both** `dc1` (001) and `admin-ws` (002) as Active.
    Two sensors online. If an agent shows `Never connected` or `Disconnected`,
    the usual causes are a wrong manager IP in `ossec.conf` or the agent service
    not started — re-check both.

## Task 4 — Catch an SSH brute-force (and fix the blind spot first)

**Objective:** From `intruder`, brute-force the `svc-backup` SSH account on
`admin-ws`, and get Wazuh to fire its built-in brute-force rule. You'll find the
agent doesn't see the attack at first — diagnose why, fix it, and try again.

??? question "Predict first"
    `admin-ws` writes every failed SSH login to `/var/log/auth.log`. The agent
    is enrolled and Active. If you run the brute-force *right now*, will Wazuh
    alert on it?

??? note "Hints"
    - Attack from `intruder`:
      `sshpass -p wrongpass ssh -o StrictHostKeyChecking=no svc-backup@10.100.10.10 true`,
      looped ~10 times.
    - After attacking, look for alerts:
      `docker exec wazuh-manager grep sshd /var/ossec/logs/alerts/alerts.json`.
    - If nothing fires: what is the agent actually *reading*? List its log
      sources — `grep -A2 '<localfile>' /var/ossec/etc/ossec.conf` on
      `admin-ws`. Is `/var/log/auth.log` in there?
    - Wazuh's stock Linux agent does **not** tail `auth.log`. Add a `localfile`
      block for it (`<log_format>syslog</log_format>`), then restart the agent.

??? note "Solution"
    ```bash
    # 1) First attack — note that nothing alerts.
    docker exec intruder bash -c '
      for i in $(seq 1 10); do
        sshpass -p wrongpass ssh -o StrictHostKeyChecking=no \
          -o ConnectTimeout=3 svc-backup@10.100.10.10 true 2>/dev/null
      done'

    # 2) Teach the agent to ship auth.log, then restart it.
    docker exec admin-ws bash -c '
      sed -i "s#</ossec_config>#  <localfile>\n    <log_format>syslog</log_format>\n    <location>/var/log/auth.log</location>\n  </localfile>\n</ossec_config>#" /var/ossec/etc/ossec.conf
      /var/ossec/bin/wazuh-control restart'

    # 3) Attack again.
    docker exec intruder bash -c '
      for i in $(seq 1 10); do
        sshpass -p wrongpass ssh -o StrictHostKeyChecking=no \
          -o ConnectTimeout=3 svc-backup@10.100.10.10 true 2>/dev/null
      done'

    # 4) Now the alerts are there.
    docker exec wazuh-manager grep -o '"id":"576[0-9]"[^}]*"description":"[^"]*"' \
      /var/ossec/logs/alerts/alerts.json | tail
    ```

??? success "Check your work"
    The **first** attack produces no SSH alerts — that was the prediction, and
    the answer is the lesson: an enrolled agent only ships the log sources in
    its config, and the stock config tails only `active-responses.log` and
    `dpkg.log`, *not* `/var/log/auth.log`. The log existed; nobody was reading
    it. This is the single most common real-world SIEM failure — the data is on
    the host, but it was never onboarded.

    After you add the `localfile` and re-attack, two rules fire: **5760**
    (`sshd: authentication failed`, level 5) for each attempt, and **5763**
    (`sshd: brute force trying to get access to the system`, level 10) once
    enough failures from one source pile up in a short window. Rule 5763 is a
    *composite* rule — it doesn't match a single line, it matches the
    *frequency* of 5760. That correlation is the whole point of a SIEM: no
    single failed login is alarming; ten in ten seconds is.

## Task 5 — Onboard Active Directory's audit log

**Objective:** Ship dc1's Samba authentication audit log to the manager and
look at what an AD auth event actually contains on the wire.

dc1 already writes structured JSON audit records to `/var/log/samba/samba.log`
(this was pre-built). Wazuh can parse JSON natively — each field becomes
queryable — but only if you tell the agent the log is JSON.

??? question "Predict first"
    Samba's audit lines are JSON objects, one per line. What single field would
    you expect to distinguish a *successful* Kerberos pre-auth from a *failed*
    one (wrong password)?

??? note "Hints"
    - Add a `localfile` on **dc1** with `<log_format>json</log_format>` and
      `<location>/var/log/samba/samba.log</location>`, then restart the agent.
    - Generate a real event: on dc1, a wrong-password `kinit` for a real user —
      `echo wrongpw | kinit administrator@LAB.CORP`.
    - To see the decoded fields, paste one trimmed JSON line into
      `/var/ossec/bin/wazuh-logtest` on the manager.

??? note "Solution"
    ```bash
    # Ship the AD audit log as JSON.
    docker exec dc1 bash -c '
      sed -i "s#</ossec_config>#  <localfile>\n    <log_format>json</log_format>\n    <location>/var/log/samba/samba.log</location>\n  </localfile>\n</ossec_config>#" /var/ossec/etc/ossec.conf
      /var/ossec/bin/wazuh-control restart'

    # Generate one good and several bad authentications.
    docker exec dc1 bash -c '
      echo P@ssw0rd1 | kinit administrator@LAB.CORP >/dev/null 2>&1
      for i in 1 2 3 4 5 6; do echo wrongpw | kinit administrator@LAB.CORP; done 2>&1 | tail -1'

    # Inspect the decoded fields (note: trim the 2 leading spaces Samba writes,
    # or logtest reports "No decoder matched").
    docker exec dc1 bash -c "grep NT_STATUS_WRONG_PASSWORD /var/log/samba/samba.log | tail -1 | sed 's/^ *//'" \
      | docker exec -i wazuh-manager /var/ossec/bin/wazuh-logtest
    ```

??? success "Check your work"
    `wazuh-logtest` shows **Phase 2** decoding the line with `name: 'json'` and
    a flat list of fields: `Authentication.status`,
    `Authentication.clientAccount`, `Authentication.serviceDescription`
    (`Kerberos KDC`), `Authentication.remoteAddress`, and so on. The field you
    predicted is **`Authentication.status`**: `NT_STATUS_OK` for a good login,
    `NT_STATUS_WRONG_PASSWORD` for a bad one. Those field names are what your
    rules in the next task will match.

    One gotcha worth internalising: Samba writes each JSON line with two leading
    spaces. The live agent strips them automatically, so ingestion works — but
    `wazuh-logtest` does *not*, so you must trim them when testing by hand. Tools
    in the pipeline disagree about whitespace; know which is which.

## Task 6 — Write detection rules for AD authentication

**Objective:** On the manager, write custom rules that (a) flag a single failed
AD authentication and (b) fire a higher-severity alert when one account fails
repeatedly — a Kerberos brute-force. Prove both fire.

Custom rules live in `/var/ossec/etc/rules/local_rules.xml` on the manager.
A composite rule uses `frequency` + `timeframe` + `<same_field>` to correlate.

??? question "Predict first"
    Your brute-force rule will require 5 failures from the *same account* inside
    a window. If two different bad usernames each fail 3 times, should it fire?
    What makes "same account" enforceable?

??? note "Hints"
    - Build a base rule matched by `<decoded_as>json</decoded_as>` plus
      `<field name="Authentication.serviceDescription">Kerberos KDC</field>`.
    - A child rule (`<if_sid>`) matches
      `<field name="Authentication.status">NT_STATUS_WRONG_PASSWORD|...</field>`.
    - The composite rule uses `<if_matched_sid>`, `frequency="5"`,
      `timeframe="120"`, and `<same_field>Authentication.clientAccount</same_field>`.
    - Reload rules with `/var/ossec/bin/wazuh-control restart`.

??? note "Solution"
    Write `/var/ossec/etc/rules/local_rules.xml` on the manager:
    ```xml
    <group name="samba_ad,">
      <rule id="100200" level="0">
        <decoded_as>json</decoded_as>
        <field name="Authentication.serviceDescription">Kerberos KDC</field>
        <description>Samba AD authentication event</description>
      </rule>

      <rule id="100201" level="5">
        <if_sid>100200</if_sid>
        <field name="Authentication.status">NT_STATUS_WRONG_PASSWORD|NT_STATUS_PREAUTH_FAILED|NT_STATUS_NO_SUCH_USER</field>
        <description>Samba AD: failed authentication</description>
        <group>authentication_failed,</group>
      </rule>

      <rule id="100202" level="10" frequency="5" timeframe="120">
        <if_matched_sid>100201</if_matched_sid>
        <same_field>Authentication.clientAccount</same_field>
        <description>Samba AD: brute force (5+ failed auths, same account)</description>
        <group>authentication_failures,</group>
      </rule>
    </group>
    ```
    ```bash
    docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
    # Generate 6 failures for one account:
    docker exec dc1 bash -c 'for i in $(seq 1 6); do echo wrongpw | kinit administrator@LAB.CORP >/dev/null 2>&1; done'
    sleep 5
    docker exec wazuh-manager grep -o '"id":"1002[0-9][0-9]"' /var/ossec/logs/alerts/alerts.json | sort | uniq -c
    ```

??? success "Check your work"
    You see rule `100201` firing once per failed login and `100202` firing once
    the fifth failure for `administrator@LAB.CORP` lands inside the 120-second
    window. The base rule `100200` is `level="0"` — it never alerts on its own;
    it exists only so the child rules have something to hang off, which is how
    you build a rule hierarchy without drowning in noise.

    The prediction: 3 + 3 from two different accounts would **not** fire 100202,
    because `<same_field>Authentication.clientAccount</same_field>` requires the
    five failures to share one account. Drop that line and your rule would alert
    on a slow spray across many usernames as if it were one brute-force — a
    classic false positive. Correlation scope is a design decision, not a
    detail.

## Task 7 — Detect new account creation (Break-It)

**Objective:** Write a rule that alerts when a new object is created in AD, then
create a user and watch your rule stay *silent*. Diagnose why the audit log
shows nothing, and fix it.

??? question "Predict first"
    You'll add a rule matching `type=dsdbChange` with operation `Add`. Then on
    dc1 you'll run `samba-tool user create eviluser ...`. The user is created
    successfully. Will your rule fire?

??? note "Hints"
    - Add this rule to `local_rules.xml`:
      ```xml
      <rule id="100210" level="8">
        <decoded_as>json</decoded_as>
        <field name="type">dsdbChange</field>
        <field name="dsdbChange.operation">Add</field>
        <description>Samba AD: directory object created</description>
        <group>policy_changed,</group>
      </rule>
      ```
    - Restart the manager, then `samba-tool user create eviluser P@ssw0rd99!`
      on dc1. Check for alerts — and check the raw audit log:
      `grep '"operation": "Add"' /var/log/samba/samba.log`.
    - It's empty. The rule isn't the problem. Where does the audit module sit —
      and does a *local* `samba-tool` call pass through it? Try creating the
      user **over the network** instead:
      `samba-tool user create ... -H ldap://dc1.lab.corp -U Administrator%P@ssw0rd1`.

??? note "Solution"
    ```bash
    # Add rule 100210 (above) to local_rules.xml, then:
    docker exec wazuh-manager /var/ossec/bin/wazuh-control restart

    # This SUCCEEDS but produces NO audit record and NO alert:
    docker exec dc1 samba-tool user create eviluser P@ssw0rd99!
    docker exec dc1 grep -c '"operation": "Add"' /var/log/samba/samba.log   # -> 0

    # This goes over LDAP, through the daemon's audit module, and DOES alert:
    docker exec dc1 samba-tool user create realhire P@ssw0rd99! \
      -H ldap://dc1.lab.corp -U Administrator%P@ssw0rd1
    sleep 5
    docker exec wazuh-manager grep '"id":"100210"' /var/ossec/logs/alerts/alerts.json | tail -1
    ```

??? success "Check your work"
    Your rule is correct — but the first create produced *no audit event at
    all*, so there was nothing to match. The symptom ("my rule doesn't fire")
    points at the wrong layer (the rule); the cause is the **audit pipeline**.
    Samba's directory audit logging lives in the LDB module stack that the
    `samba` daemon loads. A local `samba-tool user create` edits `sam.ldb`
    directly and **bypasses that stack**, so it's invisible to the audit log —
    and therefore to the SIEM. The same operation performed *over the network*
    (`-H ldap://...`) is processed by the daemon, hits the audit module, emits a
    `dsdbChange`/`Add` record, and your rule fires (level 8).

    The production lesson is uncomfortable and real: **a SIEM can only alert on
    what is audited, and not every code path is audited.** An attacker with
    local access to a DC who edits the directory database directly leaves no
    audit trail. Detection coverage is bounded by instrumentation coverage —
    always ask "what generates this event, and what doesn't?"

## Task 8 — Fire back: automatic firewall block (active response)

**Objective:** Configure Wazuh so that when the SSH brute-force rule (5763)
fires, the manager tells the *attacked agent* to drop the source IP at its
firewall. Trigger it and confirm the iptables rule appears.

??? question "Predict first"
    The active-response config goes on the **manager**, but the `iptables` rule
    ends up on **admin-ws**. How does the manager get an agent to run a command,
    and which host's firewall changes — the manager's or the agent's?

??? note "Hints"
    - The `firewall-drop` command is already defined in the manager's
      `ossec.conf`. You add an `<active-response>` block that binds it to a
      rule.
    - Use `<location>local</location>` (run on the agent that generated the
      alert), `<rules_id>5763</rules_id>`, and a `<timeout>` so the block
      auto-expires.
    - **Insert it before `</ossec_config>`** — the manager's root tag is
      `<ossec_config>`, not `<ossec>`. Restart the manager afterward.
    - Confirm the command propagated: the agent's
      `/var/ossec/etc/shared/ar.conf` should list `firewall-drop`.
    - If you tripped 5763 less than a minute ago, the composite rule won't
      re-fire instantly (it has a re-fire window) — wait ~60s and attack again.

??? note "Solution"
    Add to the manager's `/var/ossec/etc/ossec.conf`, just before
    `</ossec_config>`:
    ```xml
    <active-response>
      <command>firewall-drop</command>
      <location>local</location>
      <rules_id>5763</rules_id>
      <timeout>180</timeout>
    </active-response>
    ```
    ```bash
    docker exec wazuh-manager /var/ossec/bin/wazuh-control restart
    sleep 8
    # Confirm the agent received the command definition:
    docker exec admin-ws grep firewall-drop /var/ossec/etc/shared/ar.conf

    # Trigger the brute force again:
    docker exec intruder bash -c '
      for i in $(seq 1 12); do
        sshpass -p wrongpass ssh -o StrictHostKeyChecking=no \
          -o ConnectTimeout=3 svc-backup@10.100.10.10 true 2>/dev/null
      done'
    sleep 8
    docker exec admin-ws iptables -L INPUT -n -v
    ```

??? success "Check your work"
    After the brute-force trips rule 5763, `iptables -L INPUT` on **admin-ws**
    shows a `DROP all -- 10.100.10.66` rule that wasn't there before — the
    attacker's own subsequent packets are now dropped at the victim host. The
    prediction: the manager sends the command over the agent channel to
    `wazuh-execd` on the agent, and the **agent's** firewall changes, because
    `<location>local</location>` runs the response on the host that saw the
    attack. (Other options are `server`, or `all` to block fleet-wide.) The
    `<timeout>180</timeout>` means the block lifts itself after three minutes —
    active response is a speed bump, not a permanent ban, precisely because a
    spoofed source IP could otherwise let an attacker get you to firewall off a
    legitimate host. Automated response is powerful and double-edged; scope and
    timeout exist to contain the blast radius.

## Task 9 — Watch a file change in real time (FIM)

**Objective:** Turn on File Integrity Monitoring for a sensitive directory on
`admin-ws` and confirm Wazuh alerts the instant a file there is added or
modified.

??? note "Hints"
    - FIM is the `<syscheck>` block in the agent's `ossec.conf`. Add a
      `<directories>` entry with `realtime="yes"`, `check_all="yes"`, and
      `report_changes="yes"`.
    - Watch a directory you'll then touch, e.g. `/etc/critical` (create it
      first). Restart the agent.
    - Modify a file there and check
      `grep syscheck /var/ossec/logs/alerts/alerts.json` on the manager.

??? note "Solution"
    ```bash
    docker exec admin-ws bash -c '
      mkdir -p /etc/critical
      sed -i "s#</ossec_config>#  <syscheck>\n    <directories realtime=\"yes\" check_all=\"yes\" report_changes=\"yes\">/etc/critical</directories>\n  </syscheck>\n</ossec_config>#" /var/ossec/etc/ossec.conf
      /var/ossec/bin/wazuh-control restart'
    sleep 10
    docker exec admin-ws bash -c '
      echo "secret=changed" >> /etc/critical/app.conf
      echo new > /etc/critical/added.txt'
    sleep 8
    docker exec wazuh-manager grep syscheck /var/ossec/logs/alerts/alerts.json \
      | grep -o '"description":"[^"]*"' | tail
    ```

??? success "Check your work"
    Within seconds of the writes you get `File added to the system.` and (on a
    later edit of an existing file) `Integrity checksum changed.` alerts. Because
    you set `realtime="yes"`, detection uses the kernel's inotify and is
    near-instant rather than waiting for the periodic baseline scan (which by
    default runs every several hours). `report_changes="yes"` even records a
    diff of *what* changed inside the file. FIM is how you catch the tampering
    that authentication logs miss — a legitimately-authenticated process quietly
    editing a config or dropping a web shell.

## Task 10 — The blind spot (open)

**Objective:** You've built a sensor grid. Now find its edge. Reason about — and
then demonstrate — an attack this SIEM, as currently configured, would *not*
catch.

??? note "Hints"
    - You enrolled `dc1` and `admin-ws`. What about `intruder`? What about any
      host nobody installed the agent on?
    - You can demonstrate one blind spot in under a minute: stop the dc1 agent
      (`docker exec dc1 /var/ossec/bin/wazuh-control stop`), then brute-force AD
      again and check for alerts. Then think about what an attacker would do
      *first* on a host they've compromised.

??? note "Solution"
    There's no single answer — this is the thinking task. The cleanest
    demonstration:
    ```bash
    docker exec dc1 /var/ossec/bin/wazuh-control stop
    docker exec dc1 bash -c 'for i in $(seq 1 8); do echo wrongpw | kinit administrator@LAB.CORP >/dev/null 2>&1; done'
    sleep 5
    # No new 100202 alerts — the attack happened, the SIEM is blind.
    docker exec dc1 /var/ossec/bin/wazuh-control start   # restore
    ```

??? success "Check your work"
    Two blind spots fall out of this lab's own design:

    1. **Unmonitored hosts.** `intruder` runs no agent. An attack *originating*
       there is only visible because it *lands* on a host that is monitored
       (admin-ws). Lateral movement between two unmonitored hosts would be
       invisible. Coverage is the perimeter of your visibility.
    2. **The agent is a target.** A stopped agent ships nothing, and **stopping
       the agent is itself something an attacker does early.** With the dc1 agent
       down, your Kerberos brute-force produced no alerts at all — the events
       were written to a log nobody was reading anymore. This is why mature
       deployments alert specifically on *agent disconnection* (a SIEM watching
       its own sensors): silence is not safety, and the absence of alerts can be
       the loudest alert of all.

---

## Verification checklist

Run these after completing the lab; each re-tests an outcome, not a task.

```bash
# Both real agents enrolled and Active.
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# Your AD rules are loaded (no XML errors on the last restart).
docker exec wazuh-manager /var/ossec/bin/wazuh-logtest <<<'{"type":"Authentication","Authentication":{"serviceDescription":"Kerberos KDC","status":"NT_STATUS_WRONG_PASSWORD","clientAccount":"x@LAB.CORP"}}'
#   -> should match rule id 100201

# SSH brute force fires the built-in composite rule.
docker exec wazuh-manager grep -c '"id":"5763"' /var/ossec/logs/alerts/alerts.json

# Active response left a firewall rule on the victim.
docker exec admin-ws iptables -L INPUT -n | grep 10.100.10.66

# FIM is watching in realtime.
docker exec admin-ws grep -A1 '<syscheck>' /var/ossec/etc/ossec.conf
```

You're done when: both agents are Active; `wazuh-logtest` matches your `100201`
on a synthetic failed-auth; `5763` has fired at least once; and the iptables
DROP for the attacker is present (or recently expired — it times out after 180s).

## Challenge questions

No answers provided — these test whether you can transfer what you built.

1. Your `100202` brute-force rule fires after 5 failures in 120 seconds. An
   attacker who knows this paces their guesses to 4 every 120 seconds. Describe
   two different detection changes that would catch the slow attack, and the
   cost of each (false positives, state, latency).
2. Rule `100201` matches three `NT_STATUS_*` values. A teammate proposes
   matching *every* status that isn't `NT_STATUS_OK` instead. Argue for or
   against, and name one event that change would newly (and perhaps wrongly)
   alert on.
3. In Task 7 you saw a local `samba-tool` edit leave no audit trail. Design a
   *compensating control* — independent of Samba's audit log — that would catch
   a rogue admin creating a backdoor account directly on the DC. (Hint: you
   already configured a mechanism in this lab that could help.)
4. The active response blocks the attacker's source IP. The attacker is behind
   a NAT shared by 200 legitimate users. What happens, and how would you change
   the response policy to avoid taking out the office? Would you ever set
   `<location>all</location>`?
5. You add a second domain controller, `dc2`. List everything you must do so
   that AD authentication brute-forces are detected regardless of which DC the
   attack hits — and identify the new blind spot two DCs introduce.

## Key concepts

| Concept | What it means here |
|---------|--------------------|
| **SIEM** | Central system that ingests logs from many hosts, *decodes* them into fields, *correlates* across events, and *alerts*. Here: Wazuh manager. |
| **Agent** | Per-host package that ships configured log sources to the manager. Enrolled with a shared key; ships only what its `localfile` blocks name. |
| **Onboarding gap** | The log exists on the host but no agent source reads it (Task 4's `auth.log`). The most common reason a SIEM "misses" an attack. |
| **Decoder** | Turns a raw log line into fields. Wazuh's JSON decoder flattens nested keys to `Parent.child`, which your rules match on. |
| **Atomic vs. composite rule** | Atomic matches one event (5760, 100201). Composite matches a *pattern over time* using `frequency`/`timeframe`/`same_field` (5763, 100202). Correlation is the SIEM's real value. |
| **Active response** | Manager-triggered command run on an agent (`firewall-drop`). Scoped by `location`, bounded by `timeout` — automation with a deliberately short blast radius. |
| **FIM** | File Integrity Monitoring (`syscheck`): alerts on file add/modify/delete. `realtime` uses inotify; catches tampering that auth logs can't. |
| **Instrumentation bound** | You can only detect what something *audits*. Un-audited code paths (local `samba-tool`) and un-enrolled hosts are invisible by construction. |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `agent-auth: Unable to connect to ...1515` | Manager not ready yet | Wait until `wazuh-control status` on the manager shows processes running, then retry |
| Agent shows `Never connected` | Wrong manager IP, or agent not started | Check `<address>` in agent `ossec.conf`; `/var/ossec/bin/wazuh-control start` (not `systemctl`) |
| SSH brute force fires no alert | Agent isn't tailing `/var/log/auth.log` | Add the `localfile` (Task 4) and restart the agent |
| `wazuh-logtest` says "No decoder matched" on a Samba line | The 2 leading spaces Samba writes | Trim them (`sed 's/^ *//'`); the live agent strips them automatically |
| Custom rule never fires though events arrive | Wrong field name | Use the dotted JSON path (`Authentication.status`, `dsdbChange.operation`) exactly as `wazuh-logtest` prints it |
| New-user rule silent after `samba-tool user create` | Local edit bypasses the audit module | Create over the network: `-H ldap://dc1.lab.corp -U Administrator%P@ssw0rd1` |
| Active response never touches iptables | AR block put after `</ossec_config>` / `firewall-drop` missing from agent `ar.conf` | Insert before `</ossec_config>`; restart manager; confirm `ar.conf` lists `firewall-drop` |
| Manager won't start after editing rules | Malformed `local_rules.xml` | `wazuh-control restart` prints the XML error and line; fix and retry |

## What's next

You now have the detection layer the earlier labs were missing — and you've felt
its limits. **Lab 15 (Backup & Recovery)** is the other half of incident
response: detection tells you something happened; backups are how you recover
from it. The capstone (**Lab 16**) brings the whole environment together, where
the SIEM you built here becomes the thing that *notices* the planted faults
before the troubleshooting begins.

---

## Appendix — Optional experiment: add the indexer + dashboard

This lab runs manager-only on purpose (see the topology note). If your machine
has headroom (comfortably more than 4 GB free for Docker), you can add the
visualization layer and explore the same alerts in a browser. **This is an
experiment, not part of the graded lab** — expect higher memory use and slower
boots, and roll it back if the stack gets flaky.

The full multi-node Wazuh deployment (indexer + dashboard with TLS between every
component) is involved enough that the upstream project ships it as its own
`wazuh-docker` repository. The realistic path is to follow that repo's
single-node compose rather than hand-extend this lab's file. Two things to know
before you try:

- **Memory.** `docker info | grep Total` — the single-node indexer alone wants
  ~2 GB heap. Raise Docker Desktop's memory limit first or it will OOM-kill the
  indexer mid-boot.
- **What you gain.** Nothing about *detection* — every rule, alert, and active
  response in this lab already works manager-side. You gain dashboards,
  full-text search over historical alerts, and the agent-management UI. It's the
  analyst's console, not the detection engine.

If you do stand it up, every alert you generated above will appear under
**Security events**, and your custom rules (`100201`, `100202`, `100210`) will
show up filtered by `rule.id` — a good way to see your work rendered the way a
SOC analyst would actually consume it.
