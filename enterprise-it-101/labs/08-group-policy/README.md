# Lab 08 — Group Policy & Configuration Management

Windows enterprises enforce configuration with **Group Policy** — central rules
pushed from the domain controller. It's powerful on Windows and nearly useless
on Linux, which is the whole tension of this lab. You'll create and link a real
GPO on the DC (and see exactly why Linux can't consume it), then do the job the
way Linux shops actually do it: **Ansible** — desired-state playbooks that you
run from a control node to enforce NTP, an SSH banner, and SSH hardening across
`ws1` and `ws2`, idempotently, with drift detection.

## Topology

```
┌──────────────────────────────────────────────────────────────────────┐
│                     lab-corp  10.100.0.0/16                           │
│                                                                      │
│  ┌──────────────┐                      ┌──────────────┐              │
│  │     dc1      │  Part A: GPO          │   ansible1   │  Part B      │
│  │  Samba AD DC │  create / link /      │ control node │  ansible-    │
│  │ 10.100.1.10  │  SYSVOL              │ 10.100.3.10  │  playbook     │
│  └──────────────┘                      └──────┬───────┘              │
│                                  SSH (key) ┌───┴────┐                 │
│                                            ▼        ▼                 │
│                                     ┌──────────┐ ┌──────────┐         │
│                                     │   ws1    │ │   ws2    │         │
│                                     │10.100.10.│ │10.100.10.│         │
│                                     │   11     │ │   12     │         │
│                                     └──────────┘ └──────────┘         │
└──────────────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `dc1` | `samba-ad:local` | `10.100.1.10` | AD DC — Group Policy lives here (foundation) |
| `ansible1` | `ansible:local` (custom) | `10.100.3.10` | Ansible control node — **you write the playbooks** |
| `ws1` | `workstation:local` | `10.100.10.11` | Managed host (sshd, deliberately un-hardened) |
| `ws2` | `workstation:local` | `10.100.10.12` | Managed host |

## How to use this lab

This is a **practice lab**, not a tutorial.

- **Predict before you run.** Commit to an answer first.
- **Reveal the solution only after you've tried.** Reach for
  `samba-tool gpo --help`, `man ansible-playbook`, and the
  [Ansible docs](https://docs.ansible.com/) first.
- **Observe, don't just verify.** The `Check your work` blocks explain the
  *mechanism*.

You run `samba-tool` on `dc1` (Part A) and write/run playbooks on `ansible1`
in `/root/ansible` (Part B).

## Prerequisites

```bash
cd enterprise-it-101
docker build -t samba-ad:local   images/samba-ad/
docker build -t workstation:local images/workstation/
docker build -t ansible:local     images/ansible/
```

## Deploy

```bash
cd enterprise-it-101
docker compose -f base/docker-compose.yml \
               -f labs/08-group-policy/docker-compose.override.yml up -d
```

Wait for `dc1` to provision. Confirm Ansible can reach the hosts:
`docker exec ansible1 ssh -o BatchMode=yes root@10.100.10.11 hostname` → `ws1`.

## Destroy

```bash
docker compose -f base/docker-compose.yml \
               -f labs/08-group-policy/docker-compose.override.yml down -v
```

---

## What is pre-built

- `dc1` — the DC with the `Workstations` OU from Lab 01.
- `ansible1` — Ansible installed, the control-node SSH key in place at
  `/root/.ssh/id_ed25519`.
- `ws1` / `ws2` — running an intentionally **permissive** sshd (root login +
  password auth on) and trusting `ansible1`'s key. Your hardening playbook will
  tighten them.

## What you configure

A GPO on `dc1` (Part A); an Ansible inventory and three playbooks on `ansible1`
(Part B).

---

# Part A — Group Policy (≈30 min)

## Task 1 — Create and link a GPO, and find where it physically lives

**Objective:** Create a GPO, link it to the `Workstations` OU, and locate the
files that *are* the GPO — because understanding GPO means understanding that
it's just files in a share.

??? question "Predict first"
    When you create a GPO, where does its data physically live on the DC, and
    how does a client machine *get* it at boot/login? (Hint: you served this
    exact thing back in Lab 01 — it was one of the ports you didn't expect the
    DC to be listening on.)

??? note "Hints"
    - `samba-tool gpo create "<name>" -U Administrator`.
    - List them (and copy the GUID): `samba-tool gpo listall`.
    - Link to an OU: `samba-tool gpo setlink "OU=Workstations,DC=lab,DC=corp" "{GUID}"`.
    - Verify: `samba-tool gpo getlink "OU=Workstations,DC=lab,DC=corp"`.
    - Then look on disk under `/var/lib/samba/sysvol/lab.corp/Policies/`.

??? note "Solution"
    ```bash
    docker exec dc1 samba-tool gpo create "Workstation Lockdown Policy" \
        -U Administrator --password=P@ssw0rd1
    # copy the {GUID} it prints, then:
    GPO="{...}"
    docker exec dc1 samba-tool gpo setlink "OU=Workstations,DC=lab,DC=corp" "$GPO" \
        -U Administrator --password=P@ssw0rd1
    docker exec dc1 samba-tool gpo getlink "OU=Workstations,DC=lab,DC=corp" \
        -U Administrator --password=P@ssw0rd1
    docker exec dc1 ls /var/lib/samba/sysvol/lab.corp/Policies/
    ```

??? success "Check your work"
    `getlink` shows your GPO linked to the Workstations OU, and the
    `Policies/{GUID}/` directory exists under **SYSVOL**. That's the answer to
    the prediction: a GPO is a folder of policy files in SYSVOL, and SYSVOL is an
    **SMB share** (`\\dc1\sysvol`) on port 445 — the port that surprised you in
    Lab 01. Clients fetch the linked GPOs from that share and apply them. Group
    Policy is, mechanically, "an SMB share full of config files plus a link in
    LDAP saying which OU they apply to."

---

## Task 2 — Set a policy value, then confront the Linux problem

**Objective:** Put an actual setting in the GPO, read it back — then reckon with
the fact that your Linux workstations have no way to apply it, which is the
reason Part B exists.

??? question "Predict first"
    You'll set a password-age policy in the GPO. A *Windows* member of the
    Workstations OU would enforce it at next `gpupdate`. Will `ws1` (a Linux box)
    enforce it? What component does a Windows client have that `ws1` doesn't?

??? note "Hints"
    - `samba-tool gpo manage security set "{GUID}" MaximumPasswordAge 90 -U Administrator`.
    - Read it back: `samba-tool gpo manage security list "{GUID}" -U Administrator`.

??? note "Solution"
    ```bash
    docker exec dc1 samba-tool gpo manage security set "$GPO" MaximumPasswordAge 90 \
        -U Administrator --password=P@ssw0rd1
    docker exec dc1 samba-tool gpo manage security list "$GPO" \
        -U Administrator --password=P@ssw0rd1
    ```

??? success "Check your work"
    `list` shows `MaximumPasswordAge = 90` — the setting is now stored in the
    GPO's `GptTmpl.inf` in SYSVOL, ready for any Windows client in the OU. But
    `ws1` will **never** apply it: a Windows client runs a Group Policy *client
    engine* that parses these files and rewrites the registry/security database;
    Linux has no such engine (Samba's `samba-gpupdate` covers only a tiny subset
    and needs a full domain join). So you have a perfectly good policy that
    reaches the share and stops there. **That gap — central policy that Linux
    can't consume — is exactly what configuration-management tools fill.** On to
    Ansible.

    !!! note "If `set` prints a traceback the first time"
        The very first `security set` against a brand-new GPO sometimes errors
        while creating the GPO's `Machine\…\SecEdit` directory in SYSVOL. It's
        harmless — re-run the same command and confirm with `security list`; the
        value persists.

---

# Part B — Ansible (the core, ≈1.5–2 h)

## Task 3 — Build an inventory and confirm connectivity

**Objective:** Write an Ansible inventory listing `ws1`/`ws2` and prove the
control node can reach them.

??? question "Predict first"
    Ansible is "agentless." Given that, what must already be true on `ws1` for
    Ansible to manage it — what does it connect *over*, and what does it need on
    the target to actually run a module?

??? note "Hints"
    - Inventory (`/root/ansible/inventory.ini`): a `[workstations]` group with
      `ws1`/`ws2` and `ansible_host=` IPs.
    - Group vars: `ansible_user=root`,
      `ansible_ssh_private_key_file=/root/.ssh/id_ed25519`,
      `ansible_python_interpreter=/usr/bin/python3`.
    - Test: `ansible all -i inventory.ini -m ping`.

??? note "Solution"
    ```ini
    # /root/ansible/inventory.ini
    [workstations]
    ws1 ansible_host=10.100.10.11
    ws2 ansible_host=10.100.10.12

    [workstations:vars]
    ansible_user=root
    ansible_ssh_private_key_file=/root/.ssh/id_ed25519
    ansible_python_interpreter=/usr/bin/python3
    ```
    ```bash
    docker exec -it ansible1 bash      # then: cd /root/ansible
    ansible all -i inventory.ini -m ping
    ```

??? success "Check your work"
    Both hosts return `SUCCESS => { "ping": "pong" }`. The prediction's answer:
    "agentless" means Ansible connects over **plain SSH** (no daemon to install)
    and pushes modules that run using the target's **Python** interpreter. So the
    only prerequisites are SSH access (a key) and Python — both of which `ws1`
    already has. That low bar is why Ansible spread so fast in Linux shops.

---

## Task 4 — Write desired-state playbooks (NTP + login banner)

**Objective:** Write `enforce-ntp.yml` (point chrony at `ntp1` = `10.100.1.20`)
and `enforce-ssh-banner.yml` (deploy `/etc/issue.net` and wire sshd to it). Run
them and confirm they change the hosts.

??? question "Predict first"
    A playbook task says *what the end state should be*, not *what commands to
    run*. For the NTP config, why does describing the desired file content beat a
    shell script that `echo`s lines into `chrony.conf` — what does Ansible do on
    the **second** run that the shell script wouldn't?

??? note "Hints"
    - `ansible.builtin.copy` writes file content to a `dest`.
    - `ansible.builtin.lineinfile` ensures a single line matches a `regexp`.
    - A **handler** (`notify:`) runs only when a task changes something — use it
      to reload sshd: `sshd -t && pkill -HUP -o sshd` (validate config, then HUP
      only the *master* sshd so your own session survives).
    - Run multiple plays at once: `ansible-playbook -i inventory.ini a.yml b.yml`.

??? note "Solution"
    `/root/ansible/enforce-ntp.yml`:
    ```yaml
    ---
    - name: Enforce NTP configuration
      hosts: workstations
      tasks:
        - name: Deploy chrony.conf pointing at ntp1
          ansible.builtin.copy:
            dest: /etc/chrony/chrony.conf
            content: |
              # Managed by Ansible — do not edit by hand
              server 10.100.1.20 iburst
              driftfile /var/lib/chrony/chrony.drift
              makestep 1.0 3
              rtcsync
            mode: "0644"
    ```
    `/root/ansible/enforce-ssh-banner.yml`:
    ```yaml
    ---
    - name: Enforce SSH login banner
      hosts: workstations
      tasks:
        - name: Deploy banner text
          ansible.builtin.copy:
            dest: /etc/issue.net
            content: "Authorized access only. All activity is logged.\n"
            mode: "0644"
        - name: Point sshd at the banner
          ansible.builtin.lineinfile:
            path: /etc/ssh/sshd_config
            regexp: "^#?Banner"
            line: "Banner /etc/issue.net"
          notify: reload sshd
      handlers:
        - name: reload sshd
          ansible.builtin.shell: sshd -t && pkill -HUP -o sshd
    ```
    ```bash
    ansible-playbook -i inventory.ini enforce-ntp.yml enforce-ssh-banner.yml
    ```

??? success "Check your work"
    The `PLAY RECAP` shows `changed=…` for both hosts — the files were written,
    and the banner play's handler reloaded sshd. The prediction's answer: on the
    **second** run Ansible compares the current state to the desired state, sees
    they already match, and reports `changed=0` — it does *nothing*. A shell
    script that `echo`s lines would append duplicates or rewrite the file every
    time, never knowing whether it needed to. **Describing the end state, not the
    steps, is the entire idea** — and it's what makes the next task possible.

---

## Task 5 — Prove idempotency

**Objective:** Run the same playbooks a second time and confirm **zero**
changes. Idempotency is the property that makes config management safe to run on
a schedule.

??? question "Predict first"
    You just ran the playbooks and they reported changes. Run them again,
    unchanged. What will `changed=` be for each host, and why is that the single
    most important property of a configuration tool?

??? note "Solution"
    ```bash
    ansible-playbook -i inventory.ini enforce-ntp.yml enforce-ssh-banner.yml
    # look at the PLAY RECAP line for each host
    ```

??? success "Check your work"
    Every host reports `changed=0` — the second run is a no-op. This is
    **idempotency**: applying the desired state any number of times produces the
    same result, and the tool only acts when reality differs from intent. It's
    why you can run Ansible every 30 minutes from cron to *hold* configuration in
    place: a compliant host costs nothing, a drifted host gets corrected, and you
    never fear "what happens if this runs twice."

---

## Task 6 — Harden sshd without locking yourself out

**Objective:** Write `harden-sshd.yml` to disable password auth and X11
forwarding and restrict root login — while keeping Ansible's own key-based access
working.

??? question "Predict first"
    Ansible connects to `ws1` **as root over SSH**. If your hardening sets
    `PermitRootLogin no`, what happens to your *next* `ansible-playbook` run?
    What value lets you forbid password-based root login while still allowing
    Ansible's key to work?

??? note "Hints"
    - Loop `ansible.builtin.lineinfile` over a list of `{ key, value }` settings.
    - `PasswordAuthentication no`, `X11Forwarding no`, and — carefully —
      `PermitRootLogin prohibit-password` (key OK, password forbidden), **not**
      `no`.
    - Reuse the `reload sshd` handler.

??? note "Solution"
    `/root/ansible/harden-sshd.yml`:
    ```yaml
    ---
    - name: Harden sshd
      hosts: workstations
      tasks:
        - name: Enforce hardened sshd settings
          ansible.builtin.lineinfile:
            path: /etc/ssh/sshd_config
            regexp: "^#?{{ item.key }}"
            line: "{{ item.key }} {{ item.value }}"
          loop:
            - { key: "PasswordAuthentication", value: "no" }
            - { key: "PermitRootLogin", value: "prohibit-password" }
            - { key: "X11Forwarding", value: "no" }
          notify: reload sshd
      handlers:
        - name: reload sshd
          ansible.builtin.shell: sshd -t && pkill -HUP -o sshd
    ```
    ```bash
    ansible-playbook -i inventory.ini harden-sshd.yml
    ansible-playbook -i inventory.ini harden-sshd.yml   # idempotent: changed=0
    ```

??? success "Check your work"
    The first run changes the settings and reloads sshd; the second is
    `changed=0`. Crucially, **Ansible still connects** — because
    `PermitRootLogin prohibit-password` permits key-based root (which Ansible
    uses) while blocking password-based root. The prediction's lesson:
    `PermitRootLogin no` would have locked your control node out on the very next
    run — a classic self-inflicted outage. Config management gives you the power
    to break every host at once; that power cuts both ways, which is why you
    validate (`sshd -t`) before reloading.

---

## Task 7 — Break it: detect and correct configuration drift

**Objective (required):** Someone "temporarily" loosens a setting on `ws1` by
hand. Use Ansible's **check mode** to detect exactly which host drifted and how,
then correct it — without touching the compliant host.

??? question "Predict first"
    You'll set `PasswordAuthentication yes` on `ws1` by hand (drift), leaving
    `ws2` compliant. When you run the hardening playbook with `--check --diff`,
    what will it report for `ws1` versus `ws2`? Does `--check` *change* anything?

**Break it** — drift `ws1` by hand:
```bash
docker exec ws1 sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
docker exec ws1 grep "^PasswordAuthentication" /etc/ssh/sshd_config   # yes
```

**Detect it** — dry-run with a diff:
```bash
docker exec ansible1 bash -c 'cd /root/ansible && ansible-playbook -i inventory.ini harden-sshd.yml --check --diff'
```

**Correct it** — apply for real, then confirm:
```bash
docker exec ansible1 bash -c 'cd /root/ansible && ansible-playbook -i inventory.ini harden-sshd.yml'
docker exec ws1 grep "^PasswordAuthentication" /etc/ssh/sshd_config   # back to no
```

??? note "Diagnosis hints (try before revealing)"
    - In the `--check --diff` output, which host shows a `changed` task and a
      `-/+` diff block, and which shows only `ok`?
    - Did the `--check` run actually modify `ws1`? Re-check the file before you
      apply.

??? success "What you should observe"
    `--check --diff` reports **`changed: [ws1]`** with a diff
    (`-PasswordAuthentication yes` / `+PasswordAuthentication no`) and
    **`ok: [ws2]`** — it pinpoints the drifted host and the exact line, and
    changes **nothing** (check mode is read-only). The real run then corrects
    `ws1` (`changed`) and leaves `ws2` alone (`changed=0`). This is the
    enterprise workflow: a scheduled `--check` run is a **compliance report**
    ("who has drifted?"), and a normal run is **enforcement**. Drift is
    inevitable — someone always "just tries something" — so detection matters as
    much as the original push. You've now closed the loop Group Policy promised
    but couldn't deliver on Linux.

---

## Verification Checklist

```bash
# Part A: GPO created, linked, stored in SYSVOL
docker exec dc1 samba-tool gpo listall | grep -A1 "Workstation Lockdown"
docker exec dc1 samba-tool gpo getlink "OU=Workstations,DC=lab,DC=corp" -U Administrator --password=P@ssw0rd1

# Part B: connectivity, idempotency, drift correction
docker exec ansible1 bash -c 'cd /root/ansible && ansible all -i inventory.ini -m ping'
docker exec ansible1 bash -c 'cd /root/ansible && ansible-playbook -i inventory.ini enforce-ntp.yml enforce-ssh-banner.yml harden-sshd.yml'   # run twice → changed=0
docker exec ws1 grep -E "^(PasswordAuthentication|PermitRootLogin|X11Forwarding|Banner)" /etc/ssh/sshd_config
```

---

## Challenge Questions

1. **Why GPO survives anyway.** Given that GPO barely applies to Linux, why do
   real mixed shops still use it heavily? What does it manage that Ansible
   typically doesn't, and on which hosts?

2. **Idempotency by hand.** You're forbidden from using `lineinfile`/`copy` and
   must enforce the NTP server with `ansible.builtin.shell`. Write the command
   so the play is still idempotent (reports `changed` only when it actually
   changes something). What two things must your shell task provide?

3. **Pull vs. push.** Ansible *pushes* from a control node over SSH. Puppet/Chef
   agents *pull* on a schedule. For holding 5,000 hosts compliant against drift,
   argue which model you'd choose and what failure mode each has that the other
   doesn't.

4. **The dangerous playbook.** Task 6 showed `PermitRootLogin no` would have
   locked you out. Design two safeguards — one in *how you write* playbooks, one
   in *how you run* them — that would have caught that mistake before it hit all
   hosts.

5. **Design extension.** You want every host's `chrony.conf` to point at `ntp1`
   *and* you want a compliance dashboard showing which hosts have drifted, run
   automatically each morning. Sketch how you'd schedule the `--check` run and
   where its output would go. (Lab 13 will give you somewhere to send it.)

---

## Key Concepts

**Group Policy = files in SYSVOL + an LDAP link.** A GPO is a folder under
`\\dc1\sysvol\…\Policies\{GUID}` plus a link on an OU. Windows clients run a
policy engine that applies it; **Linux has no such engine**, so GPO is a Windows
tool that stops at the share for Linux hosts.

**Ansible fills the gap for Linux.** Agentless (SSH + Python), desired-state
(declare the end state, not the steps), and **idempotent** (only acts when
reality differs from intent — safe to run repeatedly/on a schedule).

| Concept | What it buys you |
|---------|------------------|
| Desired state | Playbooks describe *what should be*, not *how to get there* |
| Idempotency | Re-running is a no-op on compliant hosts; safe to schedule |
| Handlers (`notify`) | Run side-effects (reload sshd) only when something changed |
| Check mode (`--check --diff`) | Read-only compliance report: who drifted, and how |

**Drift is the enemy; detection is half the job.** A scheduled `--check` run
tells you who drifted; a normal run enforces. Config management lets you fix —
or break — every host at once, so validate before you reload.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `ansible … -m ping` → UNREACHABLE | sshd down, key/perms wrong | `docker logs ws1`; key is `/root/.ssh/id_ed25519` |
| `unreachable=1` after a play with a reload handler | Handler HUP'd the session's sshd | Use `pkill -HUP -o sshd` (oldest = master only) |
| Next run locks Ansible out | `PermitRootLogin no` | Use `prohibit-password` (key OK, password blocked) |
| Playbook never reports `changed=0` | A task isn't idempotent (e.g. raw `shell`) | Use `copy`/`lineinfile`, or guard `shell` with `creates`/`changed_when` |
| `samba-tool gpo manage security set` prints a traceback once | First write creating the SYSVOL inf hierarchy | Re-run and confirm with `… security list`; the value persists |
| GPO has no effect on ws1 | Linux has no GPO engine (by design) | That's the lab's point — use Ansible |

---

## What's Next

- **Lab 09 (Email Gateway)** — more service config; you could enforce its client
  settings with the same Ansible patterns.
- **Lab 13 (Monitoring)** — the natural home for a scheduled `--check`
  compliance report; you'll have a dashboard to send drift data to.
- **Lab 16 (Capstone)** — onboarding a new host means *both* joining it to the
  domain and bringing it under config management; you now have both halves.
