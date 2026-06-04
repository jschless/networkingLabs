---
title: "14 — SIEM & Security Logging"
---

!!! tip "Operations Lab 2 of 4"
    Deploy Wazuh as a SIEM, install agents across the enterprise, forward AD audit logs, generate security events, and write a custom correlation rule.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/14-siem-logging/`  
**Requires:** Foundation + Labs 05–13

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `wazuh-manager` | `wazuh/wazuh-manager:latest` | `10.100.3.30` | Wazuh SIEM manager |
| `wazuh-dashboard` | `wazuh/wazuh-dashboard:latest` | `10.100.3.31` | Wazuh web UI |
| `wazuh-indexer` | `wazuh/wazuh-indexer:latest` | `10.100.3.32` | OpenSearch index |

**Agents installed on:** `dc1`, `mail1`, `keycloak`, `ws1`

## What is Pre-Built

- Wazuh stack running (manager + indexer + dashboard)
- Agent packages available on workstations
- Samba audit logging enabled on `dc1`

!!! warning "Resource requirements"
    The Wazuh stack requires ~2 GB RAM. Ensure your host has sufficient memory before starting this lab. See the index page for per-lab resource estimates.

## What You Configure

**1. Install and register the agent on dc1**

```bash
docker exec -it dc1 bash

dpkg -i /opt/wazuh-agent.deb
sed -i 's/MANAGER_IP/10.100.3.30/' /var/ossec/etc/ossec.conf
systemctl start wazuh-agent

# Register with the manager
/var/ossec/bin/agent-auth -m 10.100.3.30
```

**2. Repeat for mail1, keycloak, ws1**

**3. Configure Samba audit log forwarding on dc1**

In `/var/ossec/etc/ossec.conf`:
```xml
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/samba/audit.log</location>
</localfile>
```

**4. Generate security events**

```bash
# Failed login attempts (triggers brute-force rule after 5)
for i in $(seq 1 5); do
  kinit baduser@LAB.CORP <<< "wrongpass" 2>/dev/null
done

# Successful login after failures
kinit alice@LAB.CORP

# File access on fs1
smbclient //fs1.lab.corp/public -k -c "ls"

# SSH login to ws1
ssh alice@ws1.lab.corp
```

**5. View events in Wazuh dashboard**

Open `https://10.100.3.31` → Security Events → filter by agent, rule level, rule group.

Find the brute-force detection alert triggered by the 5 failed logins.

**6. Write a custom rule**

In `/var/ossec/etc/rules/local_rules.xml`:
```xml
<rule id="100001" level="12">
  <if_matched_sid>5900</if_matched_sid>
  <match>samba-tool user create</match>
  <description>New AD user created</description>
  <group>ad,user_management</group>
</rule>
```

**7. Configure active response: block IP after 10 failed SSH attempts**

In `ossec.conf`:
```xml
<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>5763</rules_id>
  <timeout>600</timeout>
</active-response>
```

## Verification Commands

```bash
# Agent status on manager
/var/ossec/bin/agent_control -l

# Manager API — list agents
curl -k -u admin:admin https://10.100.3.30:55000/agents?pretty

# Generate brute-force events
for i in $(seq 1 5); do kinit baduser@LAB.CORP <<< "wrongpass" 2>/dev/null; done

# Check alerts via API
curl -k -u admin:admin \
  'https://10.100.3.30:55000/alerts?pretty&limit=10'

# Dashboard
# https://10.100.3.31
```

## What This Lab Teaches

- A **SIEM** aggregates logs from everywhere and correlates them into security alerts
- **Brute-force detection** is rule-based: N failed attempts in M seconds → alert
- **AD audit logs** are the single most valuable data source in enterprise security
- **Active response** automates incident containment — block, isolate, disable
- Difference from Lab 13: **monitoring = availability**, **SIEM = security**
- Log sources you must always collect: AD auth, firewall, mail, DNS queries, endpoint

## Experiments

- Create a correlation rule: RADIUS auth failure + AD auth failure from the same source → alert
- Configure file integrity monitoring (FIM) on `/etc/` across all agents
- Generate a rootkit-like event (modify a system binary) and verify Wazuh detects it
- Export a report of all security events from the last hour — practice incident documentation
