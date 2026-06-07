# Enterprise IT 101

Sixteen labs that walk you through building a complete mini enterprise domain (`lab.corp`) from scratch using open-source, containerized tools. Each lab takes 2-3 hours and builds on the previous one. By the end you have a fully operational enterprise stack: centralized identity, PKI, DNS, DHCP, email, SSO with MFA, file shares, configuration management, a web proxy, RADIUS, monitoring, a SIEM, and backups.

!!! note "Different from the networking labs"
    These labs use **Docker Compose**, not ContainerLab. Enterprise IT services need IP reachability and named containers — not veth pairs and L2 wiring. All containers share a single `lab-corp` bridge network on `10.100.0.0/16`.

## Prerequisites

- Docker Engine 24+ and Docker Compose v2
- 8 GB RAM minimum (16 GB recommended for the capstone)
- 20 GB free disk space
- Internet access for pulling images (first run only)
- A TOTP authenticator app (for Lab 10 MFA)

## Network Layout

| Subnet | Purpose |
|--------|---------|
| `10.100.1.0/24` | Core services — AD, DNS, NTP, CA |
| `10.100.2.0/24` | Application services — mail, Keycloak, Squid |
| `10.100.3.0/24` | Operations — monitoring, SIEM, backup |
| `10.100.10.0/24` | Workstations / clients |
| `10.100.20.0/24` | RADIUS clients / network devices |

## Custom Image Builds

Build these once before starting the labs:

```bash
docker build -t samba-ad:local    enterprise-it-101/images/samba-ad/
docker build -t workstation:local  enterprise-it-101/images/workstation/
docker build -t bind9:local        enterprise-it-101/images/bind9/
docker build -t kea:local          enterprise-it-101/images/kea/
docker build -t ansible:local      enterprise-it-101/images/ansible/
docker build -t freeradius-ad:local enterprise-it-101/images/freeradius-ad/
docker build -t squid-ad:local     enterprise-it-101/images/squid-ad/
```

Some labs additionally use registry images (pulled automatically on `up`, no build):

```bash
# Lab 09
docker pull ghcr.io/docker-mailserver/docker-mailserver:latest
# Lab 10 (SSO)
docker pull quay.io/keycloak/keycloak:26.0
docker pull postgres:15
# Lab 11 (web origins)
docker pull nginx:alpine
```

## Lab Curriculum

### Phase 1 — Foundation (Labs 01–04)

These four labs build the base infrastructure that every subsequent lab extends.

| Lab | Duration | What You Build |
|-----|----------|----------------|
| [01 Active Directory & DNS](01-active-directory.md) | 2–3 h | Samba AD DC, OUs, users, groups, Kerberos |
| [02 NTP & Time Services](02-ntp-time-services.md) | 1.5–2 h | Chrony NTP server, clock skew and Kerberos |
| [03 Certificate Authority](03-certificate-authority.md) | 2–3 h | step-ca internal CA, LDAPS, cert lifecycle |
| [04 Domain Join & Identity](04-domain-join.md) | 2–3 h | realmd + sssd workstation join, PAM/NSS |

### Phase 2 — Core Services (Labs 05–09)

| Lab | Duration | What You Build |
|-----|----------|----------------|
| [05 DNS Deep Dive](05-dns-deep-dive.md) | 2–3 h | BIND9 recursive resolver, conditional forwarding, split-horizon |
| [06 DHCP & Dynamic DNS](06-dhcp-dynamic-dns.md) | 2–3 h | ISC Kea DHCP, TSIG-authenticated DDNS updates |
| [07 File Shares & ACLs](07-file-shares.md) | 2–3 h | Samba member server, Kerberos mounts, POSIX ACLs |
| [08 Group Policy & Config Mgmt](08-group-policy.md) | 2–3 h | Samba GPO, Ansible desired-state playbooks |
| [09 Email Gateway](09-email-gateway.md) | 2–3 h | docker-mailserver, LDAP auth, SMTP/IMAP/DKIM |

### Phase 3 — Advanced Services (Labs 10–12)

| Lab | Duration | What You Build |
|-----|----------|----------------|
| [10 SSO & Federation](10-sso-federation.md) | 2–3 h | Keycloak OIDC IdP, LDAP federation, JWT, TOTP MFA |
| [11 Web Proxy & Filtering](11-web-proxy.md) | 2–3 h | Squid + Kerberos negotiate auth, group-based ACLs |
| [12 RADIUS & AD Integration](12-radius.md) | 2–3 h | FreeRADIUS, EAP-PEAP, EAP-TLS, VLAN assignment |

### Phase 4 — Operations (Labs 13–16)

| Lab | Duration | What You Build |
|-----|----------|----------------|
| [13 Monitoring & Alerting](13-monitoring.md) | 2–3 h | Prometheus, Grafana, Alertmanager, blackbox probes |
| [14 SIEM & Security Logging](14-siem-logging.md) | 2–3 h | Wazuh stack, agent deployment, correlation rules |
| [15 Backup & Disaster Recovery](15-backup-recovery.md) | 2–3 h | BorgBackup, encrypted repos, tested restores |
| [16 Capstone: The Mini Enterprise](16-capstone.md) | 3–4 h | Full-stack onboarding, break/fix scenarios |

## How Labs Stack

Labs 1–4 produce a base `docker-compose.yml` that later labs extend with override files:

```bash
# Run Lab 05 on top of the foundation
docker compose \
  -f enterprise-it-101/base/docker-compose.yml \
  -f enterprise-it-101/labs/05-dns-deep-dive/docker-compose.override.yml \
  up -d
```

The Capstone (Lab 16) provides a single unified compose file that brings up the entire stack.
