---
title: "08 — Group Policy & Configuration Management"
---

!!! tip "Core Services Lab 4 of 5"
    Apply enterprise configuration management using Samba Group Policy Objects and Ansible playbooks — and learn why idempotency and drift detection matter.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/08-group-policy-config-mgmt/`  
**Requires:** Foundation + Labs 05–07

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `ansible1` | `ubuntu:22.04` + Ansible | `10.100.3.10` | Ansible control node |

## What is Pre-Built

- Ansible installed with Kerberos auth modules
- SSH keys distributed to all workstations
- Samba GPO tools available on `dc1`

## Part A — Samba Group Policy (30 min)

**1. Create a GPO**

```bash
docker exec dc1 samba-tool gpo create "Default Workstation Policy" -U Administrator
# Note the GPO GUID in the output
```

**2. Link it to the Workstations OU**

```bash
docker exec dc1 samba-tool gpo setlink \
  "OU=Workstations,DC=lab,DC=corp" <GPO-GUID> -U Administrator
```

**3. Set a security policy (account lockout)**

```bash
docker exec dc1 samba-tool gpo manage security set <GPO-GUID> \
  LockoutBadCount 5 -U Administrator
```

**4. Apply on ws1**

```bash
docker exec ws1 samba-gpupdate --force
```

**5. Verify the policy took effect**

```bash
docker exec dc1 samba-tool gpo listall
```

## Part B — Ansible Configuration Management (1.5–2 h)

**1. Configure Ansible inventory**

In `/etc/ansible/hosts` on `ansible1`:
```ini
[workstations]
ws1.lab.corp
ws2.lab.corp
admin-ws.lab.corp

[servers]
dc1.lab.corp
mail1.lab.corp
```

**2. Write the NTP enforcement playbook**

`/etc/ansible/playbooks/enforce-ntp.yml`:
```yaml
---
- hosts: all
  become: yes
  tasks:
    - name: Ensure chrony is installed
      apt: name=chrony state=present

    - name: Configure NTP server
      lineinfile:
        path: /etc/chrony/chrony.conf
        regexp: '^server '
        line: 'server 10.100.1.20 iburst'
      notify: restart chrony

  handlers:
    - name: restart chrony
      service: name=chrony state=restarted
```

**3. Run the playbooks**

```bash
docker exec -it ansible1 bash

ansible all -i inventory.yml -m ping

ansible-playbook enforce-ntp.yml --check --diff   # dry run
ansible-playbook enforce-ntp.yml                   # apply
ansible-playbook enforce-ntp.yml                   # second run: 0 changes (idempotent)
```

## Verification Commands

```bash
# Samba GPO status
docker exec dc1 samba-tool gpo listall
docker exec dc1 samba-tool gpo getlink "OU=Workstations,DC=lab,DC=corp"

# Ansible connectivity
docker exec ansible1 ansible all -i inventory.yml -m ping

# Dry-run any playbook
docker exec ansible1 ansible-playbook enforce-ntp.yml --check --diff

# Confirm idempotency
docker exec ansible1 ansible-playbook enforce-ntp.yml | grep -E "changed|ok"
```

## What This Lab Teaches

- **Group Policy** is how Windows enterprises enforce configuration — but it has limited Linux reach
- **Ansible** fills the same role for Linux: desired-state configuration at scale
- **Idempotency**: playbooks describe what *should* be, not steps to *get there*
- **Configuration drift** is the enemy — detection is as important as enforcement
- Real enterprises use GPO and Ansible (or Puppet/Chef) side by side

## Experiments

- Manually change the NTP config on `ws1`, re-run the playbook, verify it corrects the drift
- Write a playbook that creates AD users via `samba-tool` (infrastructure-as-code)
- Set up Ansible Vault to encrypt the AD admin password in the inventory
- Write a "drift detection" playbook that reports non-compliant hosts without making changes
