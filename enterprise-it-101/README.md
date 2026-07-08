# Enterprise IT 101

A 16-lab curriculum that walks you through building a complete mini enterprise domain (`lab.corp`) from scratch using only open-source, containerized tools. Each lab takes 2-3 hours and builds on the previous ones. By the end you have a fully operational enterprise stack: centralized identity, PKI, DNS, DHCP, email, SSO with MFA, file shares, configuration management, a web proxy, RADIUS, monitoring, a SIEM, and backups.

## Prerequisites

- Docker Engine 24+ and Docker Compose v2
- 8 GB RAM minimum (16 GB recommended for the capstone)
- 20 GB free disk space
- Internet access for pulling images (first run only)
- A TOTP authenticator app (for Lab 10 MFA)

## Quick Start

Use the `eit.sh` helper — it hides the `docker compose -f base/… -f labs/…/override`
plumbing. Run it from the `enterprise-it-101/` directory:

```bash
cd enterprise-it-101

# Build the custom images (run once)
./eit.sh build

# Deploy a lab (number or full name; 01 = Active Directory)
./eit.sh up 01

# Shell into a container (fixed role names: dc1, admin-ws, dns1, mail1, ...)
./eit.sh exec 01 dc1
./eit.sh exec 01 admin-ws

# See what's running / follow logs
./eit.sh ps 01
./eit.sh logs 01

# Tear down (add -v to also wipe that lab's volumes)
./eit.sh down 01
./eit.sh down 01 -v
```

Run `./eit.sh help` for the full command list, or `./eit.sh list` to see every lab.

<details markdown="1">
<summary>What <code>./eit.sh build</code> builds (and what's pulled on demand)</summary>

The helper builds these custom images once; you can also build them by hand from
`enterprise-it-101/`:

```bash
docker build -t samba-ad:local     images/samba-ad/
docker build -t workstation:local  images/workstation/
docker build -t bind9:local        images/bind9/
docker build -t kea:local          images/kea/
docker build -t ansible:local      images/ansible/
docker build -t freeradius-ad:local images/freeradius-ad/
docker build -t squid-ad:local     images/squid-ad/
```

Some labs additionally use registry images, pulled automatically on `up` (no build):

```bash
# Lab 09 (email)
docker pull ghcr.io/docker-mailserver/docker-mailserver:latest
# Lab 10 (SSO)
docker pull quay.io/keycloak/keycloak:26.0
docker pull postgres:15
# Lab 11 (web origins)
docker pull nginx:alpine
```
</details>

<details markdown="1">
<summary>Doing it by hand (without the helper)</summary>

Lab 01 ships a standalone compose file; Labs 02–12 are override files layered on the
base network. From `enterprise-it-101/`:

```bash
# Lab 01 (standalone)
docker compose -f labs/01-active-directory/docker-compose.yml up -d

# Labs 02–12 (base + override)
docker compose \
  -f base/docker-compose.yml \
  -f labs/05-dns-deep-dive/docker-compose.override.yml up -d
```
</details>

<!-- site:curriculum -->

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

<!-- site:curriculum-end -->

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

## Reality Notes: Samba vs Windows AD

This curriculum builds a real Active Directory domain using **Samba AD DC** and Linux
tooling because it's free, scriptable, and runs in a container. Everything you learn —
Kerberos, LDAP, GPO, DNS-integrated AD, RADIUS-against-AD — is the same protocol-level
knowledge you'd use against a Windows domain. But the **admin surface is different**: in a
real shop you'd manage AD from a Windows admin workstation with **RSAT** (Remote Server
Administration Tools — the MMC snap-ins plus the `ActiveDirectory` PowerShell module),
not from a Linux shell with `samba-tool`.

A few structural caveats worth internalizing before you carry this to a job:

- **Functional level.** Samba AD presents roughly a **Windows Server 2008 R2** forest/domain
  functional level. Newer-FFL features (the AD Recycle Bin, fine-grained password policies
  via PSOs in some tooling, gMSAs, claims-based access control) are partially or not
  supported. Don't assume a feature exists just because it's in a modern Windows AD.
- **GPOs are stored, not enforced (on Linux).** Samba stores Group Policy Objects in
  SYSVOL exactly like Windows, and a real *Windows* client would apply them. Our Linux
  clients do **not** have a native client-side extension that applies GPO — Lab 08 uses
  **Ansible** to enforce config, which is what you'd actually reach for on Linux. On
  Windows the equivalent is GPO client-side processing (`gpupdate /force`), with DSC /
  Intune / SCCM for anything GPO can't express.
- **`samba-tool` ≈ dcpromo + the AD PowerShell module.** One CLI on the DC does the
  promotion *and* the day-to-day object management. In Windows those are separate:
  `Install-ADDSForest` to promote, then RSAT/PowerShell from a *separate* admin box.

### PowerShell / RSAT equivalents per lab

What we do with Linux tooling → what you'd do against a Windows domain. Use this as a
translation key when you move to a Windows environment.

| Lab | This lab (Samba / Linux) | Windows AD equivalent (RSAT / PowerShell) |
|-----|--------------------------|-------------------------------------------|
| 01 Active Directory & DNS | `samba-tool domain provision`, `samba-tool user/group add`; Samba internal DNS | `Install-ADDSForest`; `New-ADUser` / `New-ADGroup` (ADUC, `dsa.msc`); DNS Manager (`dnsmgmt.msc`), `Add-DnsServerResourceRecord` |
| 02 NTP & Time | `chrony` hierarchy on Linux | W32Time service; `w32tm /config /query`; the **PDC emulator** FSMO role is the authoritative domain time source |
| 03 CA & PKI | `step-ca` internal CA, LDAPS | **AD Certificate Services (ADCS)**; `certutil`, certificate templates, GPO auto-enrollment |
| 04 Domain Join & Identity | `realmd` + `sssd`, cached creds | `Add-Computer -DomainName`; Windows caches domain creds natively; `gpupdate` |
| 05 DNS Deep Dive | BIND9 views, conditional forwarding | Conditional forwarders + **DNS Policies / zone scopes**; `Add-DnsServerConditionalForwarderZone` |
| 06 DHCP & DDNS | ISC Kea + DDNS into Samba DNS | DHCP Server role; `Add-DhcpServerv4Scope`; secure dynamic updates + the `DnsUpdateProxy` group |
| 07 File Shares & ACLs | Samba shares + POSIX ACLs | `New-SmbShare`; NTFS ACLs (`icacls`); File Server Resource Manager; Access-Based Enumeration |
| 08 Group Policy & Config Mgmt | Samba GPO store + **Ansible** enforcement | GPMC (`gpmc.msc`), `New-GPO` / `Set-GPRegistryValue`, `gpupdate`; DSC / Intune for the Ansible-style layer |
| 09 Email Gateway | Postfix + Dovecot, LDAP auth, DKIM | **Exchange Server** / Exchange Online; `New-Mailbox`; connectors + transport rules |
| 10 SSO & Federation | Keycloak IdP, OIDC, MFA | **AD FS** (`Install-AdfsFarm`) or **Entra ID** (Azure AD); Conditional Access for MFA |
| 11 Web Proxy & Filtering | Squid + Kerberos negotiate | Commercial proxy / Web Application Proxy; IWA via SPNs (`setspn`) |
| 12 RADIUS & AD | FreeRADIUS, EAP-PEAP/TLS, AD group → VLAN | **NPS** (Network Policy Server) role; connection-request + network policies keyed on AD groups |
| 13 Monitoring | Prometheus + Grafana + blackbox | **SCOM** (System Center Operations Manager); Performance Monitor; Windows Admin Center |
| 14 SIEM & Logging | Wazuh manager + agents | **Microsoft Sentinel**; Windows Event Forwarding (WEF/WEC); Defender for Identity |
| 15 Backup & Recovery | BorgBackup; `borg extract` restore | Windows Server Backup (`wbadmin`); **`ntdsutil`** authoritative/non-authoritative AD restore; AD Recycle Bin; DPM / Azure Backup |
| 16 Capstone | Integrated troubleshooting across the stack | Same workflow; tools above plus the AD Administrative Center and Event Viewer |

### A note on IPv6 (out of scope)

These labs are **IPv4-only by design**. The `lab-corp` network is a single IPv4 bridge
(`10.100.0.0/16`), and every service — AD, DNS, DHCP, RADIUS — is configured for v4 only.
This is a deliberate scope cut, not an oversight: it keeps addressing legible while you're
learning the *services*, and it mirrors the reality that most enterprise **internal**
networks are still IPv4-primary even where the perimeter is dual-stacked.

A real dual-stack deployment would add, at minimum: `AAAA` records alongside `A` in
AD-integrated DNS (and the matching `ip6.arpa` reverse zones); **DHCPv6 or SLAAC** for
client addressing (Kea speaks DHCPv6 — `kea-dhcp6` — but we don't enable it); and v6
listeners/ACLs on every service that currently binds v4 only. None of that changes the
identity, Kerberos, or PKI concepts these labs teach — it's an addressing-plane exercise
layered on top. If you want to pursue it, start in **Lab 05 (DNS)** and **Lab 06 (DHCP)**,
since those are where the addressing plane actually lives; the rest of the stack inherits
whatever those two hand it.

<!-- site:contributing -->

## Contributing a Lab

The series follows a strict practice-lab format so every lab teaches the same
way and at a predictable difficulty. Before authoring or revising a lab, read:

- **[`AUTHORING.md`](AUTHORING.md)** — the authoring contract: difficulty bands,
  task anatomy (objective → predict → hints → solution → check), required
  sections, and the pre-publish checklist.
- **[`DESIGN.md`](DESIGN.md)** — the curriculum vision and per-lab scope.
- **`labs/01-active-directory/`** — the reference implementation of every rule.
