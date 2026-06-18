---
title: Enterprise IT 101
---

!!! note "Different from the networking labs"
    These labs use **Docker Compose**, not ContainerLab. Enterprise IT services need IP
    reachability and named containers — not veth pairs and L2 wiring. All containers share a
    single `lab-corp` bridge network on `10.100.0.0/16`.

{%
  include-markdown "../../../enterprise-it-101/README.md"
  end="<!-- site:curriculum -->"
%}

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

### Phase 3 — Integration (Labs 10–12)

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

{%
  include-markdown "../../../enterprise-it-101/README.md"
  start="<!-- site:curriculum-end -->"
  end="<!-- site:contributing -->"
%}
