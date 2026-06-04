# Enterprise IT 101

A 16-lab curriculum that builds a complete mini enterprise domain (`lab.corp`) from scratch using open-source, containerized tools. Each lab takes 2-3 hours and builds on the previous ones.

By the end you have: centralized identity (AD), PKI, DNS, DHCP, email, SSO with MFA, file shares, configuration management, a web proxy, RADIUS, monitoring, a SIEM, and backups.

## Foundation (Labs 1-4)

| Lab | Duration | What You Build |
|-----|----------|----------------|
| [01 Active Directory](01-active-directory.md) | 2-3 hrs | Samba AD DC — LDAP, Kerberos, DNS |
| 02 NTP & Time Services | 1.5-2 hrs | Chrony NTP hierarchy, Kerberos clock-skew demo |
| 03 Certificate Authority | 2-3 hrs | step-ca internal CA, LDAPS, certificate lifecycle |
| 04 Domain Join | 2-3 hrs | realmd + sssd, Linux domain join, cached credentials |

## Core Services (Labs 5-9)

| Lab | Duration | What You Build |
|-----|----------|----------------|
| 05 DNS Deep Dive | 2-3 hrs | BIND9, conditional forwarding, split-horizon |
| 06 DHCP & DDNS | 2-3 hrs | ISC Kea DHCP, dynamic DNS updates |
| 07 File Shares | 2-3 hrs | Samba file server, AD group ACLs |
| 08 Group Policy | 2-3 hrs | Samba GPO + Ansible config management |
| 09 Email Gateway | 2-3 hrs | Postfix + Dovecot with LDAP auth |

## Integration (Labs 10-12)

| Lab | Duration | What You Build |
|-----|----------|----------------|
| 10 SSO & Federation | 2-3 hrs | Keycloak, OIDC, LDAP federation, MFA |
| 11 Web Proxy | 2-3 hrs | Squid with Kerberos auth, group-based filtering |
| 12 RADIUS | 2-3 hrs | FreeRADIUS, EAP-PEAP/TLS, VLAN assignment |

## Operations (Labs 13-16)

| Lab | Duration | What You Build |
|-----|----------|----------------|
| 13 Monitoring | 2-3 hrs | Prometheus + Grafana + alerting |
| 14 SIEM & Logging | 2-3 hrs | Wazuh SIEM, brute-force detection |
| 15 Backup & Recovery | 2-3 hrs | BorgBackup, AD restore, key recovery |
| 16 Capstone | 3-4 hrs | Full stack: onboard, troubleshoot, document |

## Recommended Order

```
Lab 01 → 02 → 03 → 04  (foundation — do these in order)
    ↓
Labs 05-09  (core services — flexible order, but 05 before 06)
    ↓
Labs 10-12  (integration — flexible order)
    ↓
Labs 13-14  (operations — either order)
    ↓
Lab 15 → 16  (backup before capstone)
```

## Platform

All labs use **Docker Compose** with custom images:

```bash
cd enterprise-it-101
docker compose -f labs/01-active-directory/docker-compose.yml build
```
