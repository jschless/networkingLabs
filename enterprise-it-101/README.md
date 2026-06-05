# Enterprise IT 101

A 16-lab curriculum that walks you through building a complete mini enterprise domain (`lab.corp`) from scratch using only open-source, containerized tools. Each lab takes 2-3 hours and builds on the previous ones. By the end you have a fully operational enterprise stack: centralized identity, PKI, DNS, DHCP, email, SSO with MFA, file shares, configuration management, a web proxy, RADIUS, monitoring, a SIEM, and backups.

## Prerequisites

- Docker Engine 24+ and Docker Compose v2
- 8 GB RAM minimum (16 GB recommended for the capstone)
- 20 GB free disk space
- Internet access for pulling images (first run only)
- A TOTP authenticator app (for Lab 10 MFA)

## Quick Start

```bash
# Build custom images (run once)
cd enterprise-it-101
docker compose -f labs/01-active-directory/docker-compose.yml build

# Deploy Lab 01
docker compose -f labs/01-active-directory/docker-compose.yml up -d

# Shell into the domain controller
docker exec -it dc1 bash

# Shell into the admin workstation
docker exec -it admin-ws bash

# Tear down
docker compose -f labs/01-active-directory/docker-compose.yml down -v
```

## Curriculum

### Phase 1 — Foundation (Labs 1-4)

These four labs create the base infrastructure that every subsequent lab depends on.

| # | Lab | Duration | What You Build |
|---|-----|----------|----------------|
| 01 | [Active Directory & DNS](labs/01-active-directory/) | 2-3 hrs | Samba AD DC — LDAP, Kerberos, DNS |
| 02 | NTP & Time Services | 1.5-2 hrs | Chrony NTP hierarchy, Kerberos clock-skew demo |
| 03 | Certificate Authority & PKI | 2-3 hrs | step-ca internal CA, LDAPS, certificate lifecycle |
| 04 | Domain Join & Identity | 2-3 hrs | realmd + sssd, Linux domain join, cached credentials |

### Phase 2 — Core Services (Labs 5-9)

| # | Lab | Duration | What You Build |
|---|-----|----------|----------------|
| 05 | DNS Deep Dive | 2-3 hrs | BIND9 recursive resolver, conditional forwarding, split-horizon |
| 06 | DHCP & Dynamic DNS | 2-3 hrs | ISC Kea DHCP, DDNS updates to Samba DNS |
| 07 | File Shares & ACLs | 2-3 hrs | Samba file server, AD group-based access, POSIX ACLs |
| 08 | Group Policy & Config Mgmt | 2-3 hrs | Samba GPO + Ansible for Linux config enforcement |
| 09 | Email Gateway | 2-3 hrs | Postfix + Dovecot with LDAP auth, DKIM, spam filtering |

### Phase 3 — Integration (Labs 10-12)

| # | Lab | Duration | What You Build |
|---|-----|----------|----------------|
| 10 | SSO & Federation | 2-3 hrs | Keycloak IdP, OIDC, LDAP federation, MFA |
| 11 | Web Proxy & Filtering | 2-3 hrs | Squid with Kerberos negotiate auth, AD group ACLs |
| 12 | RADIUS & AD Integration | 2-3 hrs | FreeRADIUS, EAP-PEAP/TLS, VLAN assignment |

### Phase 4 — Operations (Labs 13-16)

| # | Lab | Duration | What You Build |
|---|-----|----------|----------------|
| 13 | Monitoring & Alerting | 2-3 hrs | Prometheus + Grafana + blackbox probes |
| 14 | SIEM & Security Logging | 2-3 hrs | Wazuh SIEM, brute-force detection, active response |
| 15 | Backup & Disaster Recovery | 2-3 hrs | BorgBackup, AD restore, CA key recovery |
| 16 | Capstone | 3-4 hrs | Full stack: onboard a user, troubleshoot breaks, document architecture |

## Architecture

All containers share a single Docker bridge network (`lab-corp`, `10.100.0.0/16`):

| Subnet | Purpose |
|--------|---------|
| `10.100.1.0/24` | Core services (AD, DNS, NTP, CA) |
| `10.100.2.0/24` | Application services (mail, Keycloak, Squid) |
| `10.100.3.0/24` | Operations (monitoring, SIEM, backup) |
| `10.100.10.0/24` | Workstations / clients |
| `10.100.20.0/24` | RADIUS clients / network devices |

## Design Principles

1. **Docker Compose, not ContainerLab.** These labs are service-oriented, not topology-oriented.
2. **Cumulative state.** Labs 1-4 produce a foundation that every subsequent lab extends.
3. **Practice-lab style.** Core infrastructure is pre-wired; interesting config is left for you.
4. **CLI-first, GUI-assisted.** Learn the commands first, then verify visually in web UIs.

## Contributing a Lab

The series follows a strict practice-lab format so every lab teaches the same
way and at a predictable difficulty. Before authoring or revising a lab, read:

- **[`AUTHORING.md`](AUTHORING.md)** — the authoring contract: difficulty bands,
  task anatomy (objective → predict → hints → solution → check), required
  sections, and the pre-publish checklist.
- **[`DESIGN.md`](DESIGN.md)** — the curriculum vision and per-lab scope.
- **`labs/01-active-directory/`** — the reference implementation of every rule.
