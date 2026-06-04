# Enterprise IT 101 — Design Document

## Vision

A 16-lab curriculum that walks a network engineer through building a complete
mini enterprise domain (`lab.corp`) from scratch using only open-source,
containerized tools. Each lab takes 2-3 hours and builds on the previous ones,
so by the end the student has a fully operational enterprise stack: centralized
identity, PKI, DNS, DHCP, email, SSO with MFA, file shares, configuration
management, a web proxy, RADIUS, monitoring, a SIEM, and backups.

## Design principles

1. **Docker Compose, not ContainerLab.** These labs are service-oriented, not
   topology/link-oriented. ContainerLab adds value when you need veth pairs,
   bridge domains, and specific L2/L3 wiring. Enterprise IT services just need
   IP reachability and named containers — docker-compose handles this natively.

2. **Cumulative state.** Labs 1-4 (Foundation phase) produce a base
   `docker-compose.yml` and config tree that every subsequent lab extends. The
   student never starts from zero after Lab 1. Each lab's directory contains a
   `docker-compose.override.yml` (or additions to the base) and new config
   files.

3. **Practice-lab style.** Following the existing repo convention: core
   infrastructure is pre-wired, but the interesting services/config are left for
   the student to implement. README files include commented hints, verification
   commands, and "break things" experiments.

4. **Single shared network.** All containers attach to a `lab-corp` Docker
   bridge network on `10.100.0.0/16`. Subnets:
   - `10.100.1.0/24` — core services (AD, DNS, NTP, CA)
   - `10.100.2.0/24` — application services (mail, Keycloak, Squid)
   - `10.100.3.0/24` — operations (monitoring, SIEM, backup)
   - `10.100.10.0/24` — workstations / clients
   - `10.100.20.0/24` — RADIUS clients / network devices

5. **Separate from networking labs.** Lives under `enterprise-it-101/` at the
   repo root, not under `labs/`. Gets its own section in the mkdocs nav.

6. **CLI-first, GUI-assisted.** Real Windows AD administration is heavily GUI
   (ADUC, GPMC, DNS Manager). Since we use Samba (CLI-driven), we include
   **LDAP Account Manager (LAM)** as a web GUI that runs alongside the CLI
   workflow. Students learn the commands first (scriptable, automatable), then
   verify and explore visually in LAM — mirroring how Windows admins use ADUC
   daily but automate with PowerShell. Other labs with GUIs (Keycloak, Grafana,
   Wazuh Dashboard) use them as primary interfaces where that's how the tool is
   actually operated in production.

---

## Repository structure

```
enterprise-it-101/
├── DESIGN.md                          # This file
├── README.md                          # Series overview, prerequisites, curriculum map
├── base/
│   ├── docker-compose.yml             # Foundation containers (built in Labs 1-4)
│   └── .env                           # Domain name, passwords, subnet vars
├── images/
│   ├── samba-ad/
│   │   └── Dockerfile                 # Samba AD DC with supervisord
│   ├── workstation/
│   │   └── Dockerfile                 # Ubuntu + sssd + realm + krb5 + CLI tools
│   ├── freeradius-ad/
│   │   └── Dockerfile                 # FreeRADIUS with LDAP + EAP-TLS modules
│   └── squid-ad/
│       └── Dockerfile                 # Squid with Kerberos negotiate auth
├── labs/
│   ├── 01-active-directory/
│   │   ├── docker-compose.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── smb.conf
│   │       └── provision.sh           # samba-tool domain provision script
│   ├── 02-ntp-time-services/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── chrony-server.conf
│   │       └── chrony-client.conf
│   ├── 03-certificate-authority/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       └── ca-init.sh             # step-ca bootstrap + root CA creation
│   ├── 04-domain-join/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── krb5.conf
│   │       ├── sssd.conf
│   │       └── realm-join.sh
│   ├── 05-dns-deep-dive/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── named.conf
│   │       ├── db.lab.corp
│   │       └── db.external.example
│   ├── 06-dhcp-dynamic-dns/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── kea-dhcp4.conf
│   │       └── kea-ddns.conf
│   ├── 07-file-shares/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       └── smb-fileserver.conf
│   ├── 08-group-policy-config-mgmt/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── playbooks/
│   │       │   ├── inventory.yml
│   │       │   ├── enforce-ntp.yml
│   │       │   └── enforce-ssh-banner.yml
│   │       └── gpo/
│   │           └── README.md          # Samba GPO walkthrough
│   ├── 09-email-gateway/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── mailserver.env
│   │       └── postfix-main.cf
│   ├── 10-sso-federation/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── keycloak-realm.json
│   │       └── sample-app/
│   │           └── Dockerfile         # Tiny Flask/Node app with OIDC
│   ├── 11-web-proxy/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── squid.conf
│   │       └── squid-krb5.keytab.md   # Instructions (keytab generated at runtime)
│   ├── 12-radius/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── radiusd.conf
│   │       ├── mods-available/
│   │       │   ├── ldap
│   │       │   └── eap
│   │       ├── clients.conf
│   │       └── sites-available/
│   │           └── default
│   ├── 13-monitoring/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── prometheus.yml
│   │       ├── alertmanager.yml
│   │       └── grafana/
│   │           ├── datasources.yml
│   │           └── dashboards/
│   │               └── lab-corp-overview.json
│   ├── 14-siem-logging/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── wazuh-manager.conf
│   │       ├── ossec-agent.conf
│   │       └── rsyslog-forward.conf
│   ├── 15-backup-recovery/
│   │   ├── docker-compose.override.yml
│   │   ├── README.md
│   │   └── configs/
│   │       ├── backup-schedule.sh
│   │       └── restore-ad.sh
│   └── 16-capstone/
│       ├── docker-compose.yml         # Full stack, all services
│       ├── README.md
│       └── configs/
│           └── break-scripts/
│               ├── break-dns.sh
│               ├── break-kerberos.sh
│               └── break-email.sh
```

---

## Lab-by-lab design

---

### Lab 01 — Active Directory & DNS

**Duration:** 2-3 hours

**Containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `dc1` | `samba-ad:local` (custom) | `10.100.1.10` | Samba AD Domain Controller |
| `admin-ws` | `workstation:local` (custom) | `10.100.10.10` | Admin workstation with ldap-utils, krb5-user |
| `lam` | `ghcr.io/ldapaccountmanager/lam:stable` | `10.100.1.11` | LDAP Account Manager web GUI |

**Custom image: `samba-ad:local`**
- Base: `ubuntu:22.04`
- Packages: `samba`, `samba-dsdb-modules`, `samba-vfs-modules`, `krb5-user`,
  `krb5-kdc`, `winbind`, `libnss-winbind`, `libpam-winbind`, `supervisor`,
  `dnsutils`, `ldap-utils`
- Entrypoint: supervisord managing `samba` process

**Custom image: `workstation:local`**
- Base: `ubuntu:22.04`
- Packages: `sssd`, `sssd-ad`, `realmd`, `krb5-user`, `ldap-utils`,
  `adcli`, `samba-common-bin`, `dnsutils`, `curl`, `vim`, `net-tools`,
  `iputils-ping`, `chrony`, `wpa-supplicant`, `nfs-common`, `cifs-utils`
- This image is reused in every subsequent lab as the standard workstation.

**What is pre-built:**
- Docker network `lab-corp` (10.100.0.0/16)
- Samba container with a provision script ready to run
- DNS resolution pointed at dc1

**What the student configures:**
1. Provision the domain: run `samba-tool domain provision` with
   `--realm=LAB.CORP --domain=LAB --server-role=dc --dns-backend=SAMBA_INTERNAL`
2. Start Samba, verify it's listening (port 389, 88, 53, 636)
3. Create organizational units: `samba-tool ou create "OU=Employees,DC=lab,DC=corp"`
4. Create users: `samba-tool user create alice P@ssw0rd1 --given-name=Alice --surname=Smith`
5. Create groups: `samba-tool group add engineering` and add alice to it
6. From admin-ws: verify DNS (`dig @10.100.1.10 dc1.lab.corp`),
   LDAP (`ldapsearch -H ldap://dc1.lab.corp -b "DC=lab,DC=corp"`),
   and Kerberos (`kinit alice@LAB.CORP`, `klist`)

**Verification commands:**
```bash
# DNS
dig @10.100.1.10 lab.corp SOA
dig @10.100.1.10 _ldap._tcp.lab.corp SRV

# LDAP
ldapsearch -H ldap://dc1.lab.corp -b "DC=lab,DC=corp" -D "alice@lab.corp" -W "(objectClass=user)"

# Kerberos
kinit alice@LAB.CORP
klist
kvno ldap/dc1.lab.corp@LAB.CORP
```

**What this lab teaches:**
- AD is three services in a trenchcoat: LDAP (directory), Kerberos (auth), DNS (service location)
- SRV records are how clients find domain controllers — not static config
- OUs are organizational containers; groups are permission containers — different purposes
- `kinit` + `klist` is how you debug Kerberos, not logs

**GUI exploration — LDAP Account Manager (LAM):**

In a real Windows enterprise, AD administration happens in GUI tools like Active
Directory Users & Computers (ADUC) and Group Policy Management Console (GPMC).
Samba's `samba-tool` CLI is more scriptable, but the visual experience matters
for building intuition about directory structure.

LAM (`https://lam.lab.corp:443`) provides a web-based GUI for managing the
Samba AD directory. After completing the CLI steps above, the student should:

1. Open LAM in a browser, configure it to connect to `ldap://dc1.lab.corp`
   with base DN `DC=lab,DC=corp`
2. Browse the OU tree visually — see how `OU=Employees` nests under the domain root
3. Click into alice's user object — see all LDAP attributes (displayName, memberOf,
   userPrincipalName, objectSID, etc.)
4. Create a user via the GUI (bob), then verify via CLI: `samba-tool user list`
5. Compare the experience: GUI shows you the full attribute set and tree structure
   at a glance; CLI is faster for scripting and bulk operations

This mirrors the real-world workflow: Windows admins use ADUC daily, but
automation uses PowerShell/CLI. Both perspectives matter.

**Experiments:**
- Delete the `_ldap._tcp.lab.corp` SRV record, then try `kinit` from admin-ws — watch it fail
- Create a Group Policy Object with `samba-tool gpo create` (preview of Lab 08)
- Add a second user and test cross-user LDAP search permissions
- In LAM, explore the `CN=Configuration` and `CN=Schema` partitions to see AD's internal structure

---

### Lab 02 — NTP & Time Services

**Duration:** 1.5-2 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `ntp1` | `ubuntu:22.04` + chrony | `10.100.1.20` | Stratum-2 NTP server |

**Existing containers modified:** `dc1` (chrony client), `admin-ws` (chrony client)

**What is pre-built:**
- chrony installed on all nodes
- `ntp1` configured as server but deliberately pointing at an unreachable upstream

**What the student configures:**
1. Fix `ntp1` chrony config: set `server pool.ntp.org iburst` (or local refclock
   if offline) as the upstream source
2. Configure `dc1` and `admin-ws` to use `ntp1` as their NTP server:
   `server 10.100.1.20 iburst`
3. Verify sync: `chronyc sources`, `chronyc tracking`
4. Deliberately skew `admin-ws` clock by 10 minutes: `date -s "+10 min"`
5. Attempt `kinit alice@LAB.CORP` — observe "Clock skew too great" error
6. Fix the clock (`chronyc makestep`), retry Kerberos — it works

**Verification commands:**
```bash
chronyc sources -v
chronyc tracking
timedatectl status
# Kerberos clock-skew test
date -s "+10 min" && kinit alice@LAB.CORP   # fails
chronyc makestep && kinit alice@LAB.CORP     # works
```

**What this lab teaches:**
- Kerberos has a 5-minute clock skew tolerance — NTP isn't optional in an AD environment
- NTP is hierarchical: stratum 1 → stratum 2 → clients
- `chronyc sources` is the first command when auth mysteriously breaks
- Time-related failures are silent and confusing — they don't say "clock is wrong"

**Experiments:**
- Set different offsets (3 min, 5 min, 6 min) to find the exact Kerberos tolerance
- Configure chrony to log to syslog, then correlate time corrections with auth failures
- Set up `dc1` as a secondary NTP server and test failover

---

### Lab 03 — Certificate Authority & PKI

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `ca1` | `smallstep/step-ca:latest` | `10.100.1.30` | Internal certificate authority |

**What is pre-built:**
- step-ca container running but not bootstrapped
- A helper script `ca-init.sh` that the student runs to create the root CA

**What the student configures:**
1. Initialize the CA: `step ca init --name="Lab Corp CA" --dns=ca1.lab.corp
   --address=:443 --provisioner="admin@lab.corp"`
2. Register the CA's DNS name in Samba DNS:
   `samba-tool dns add dc1.lab.corp lab.corp ca1 A 10.100.1.30`
3. Bootstrap trust on admin-ws: `step ca bootstrap --ca-url https://ca1.lab.corp
   --fingerprint <root-fingerprint>`
4. Issue a certificate for dc1: `step ca certificate dc1.lab.corp dc1.crt dc1.key`
5. Configure Samba for LDAPS: add `tls enabled = yes`, `tls keyfile`,
   `tls certfile`, `tls cafile` to `smb.conf`, restart Samba
6. Verify LDAPS from admin-ws:
   `ldapsearch -H ldaps://dc1.lab.corp -b "DC=lab,DC=corp"`
7. Issue a wildcard cert for `*.lab.corp` to use in later labs

**Key concepts covered:**
- Root CA vs intermediate CA (step-ca supports both; we use single-tier for simplicity)
- Certificate lifecycle: request → issue → install → verify → renew
- Why internal CAs exist (you can't get a public cert for `.corp`)
- The trust chain: clients must have the root CA cert installed

**Verification commands:**
```bash
# Check CA is running
step ca health --ca-url https://ca1.lab.corp

# Verify cert details
openssl x509 -in dc1.crt -text -noout | grep -E "Issuer|Subject|Not After"

# Test LDAPS
openssl s_client -connect dc1.lab.corp:636 -CAfile /root/.step/certs/root_ca.crt

# Verify trust chain
step certificate verify dc1.crt --roots /root/.step/certs/root_ca.crt
```

**What this lab teaches:**
- Every encrypted service in an enterprise needs a certificate from somewhere
- Public CAs won't issue certs for internal domains — you need an internal CA
- LDAPS is just LDAP + TLS, but the trust chain must be complete or clients reject it
- `openssl s_client` and `step certificate verify` are the debugging tools

**Experiments:**
- Let a certificate expire (issue one with `--not-after=2m`) and watch LDAPS break
- Create an intermediate CA and issue certs from it instead
- Revoke a certificate and test if Samba still accepts connections (CRL/OCSP discussion)

---

### Lab 04 — Domain Join & Identity

**Duration:** 2-3 hours

**Existing containers modified:** `admin-ws` (joins domain)

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `ws1` | `workstation:local` | `10.100.10.11` | Employee workstation |
| `ws2` | `workstation:local` | `10.100.10.12` | Second workstation |

**What is pre-built:**
- Workstation images have sssd, realmd, krb5-user installed
- `/etc/resolv.conf` pointed at dc1
- `/etc/krb5.conf` template with LAB.CORP realm

**What the student configures:**
1. From ws1, discover the domain: `realm discover lab.corp`
2. Join the domain: `realm join -U Administrator lab.corp`
3. Verify join: `realm list`, check `/etc/sssd/sssd.conf` was auto-generated
4. Test AD login: `su - alice@lab.corp`, `id alice@lab.corp`
5. Configure sssd for short-name login: `use_fully_qualified_names = False`
   in sssd.conf, restart sssd, test `su - alice`
6. Verify home directory creation: `ls /home/alice@lab.corp/`
7. Test group-based sudo: add engineering group to sudoers, verify alice can sudo
8. Join ws2 the same way, verify both workstations appear in AD:
   `samba-tool computer list`

**Verification commands:**
```bash
# Domain discovery
realm discover lab.corp

# After join
realm list
id alice@lab.corp
getent passwd alice@lab.corp
getent group engineering@lab.corp

# Kerberos ticket from domain user
su - alice@lab.corp -c "klist"

# See computer accounts in AD
docker exec dc1 samba-tool computer list
```

**GUI checkpoint — LAM:**

After joining both workstations, open LAM and navigate to the Computers container.
The student should see `ws1$` and `ws2$` machine accounts alongside `admin-ws$`.
Click into a computer object to see attributes like `operatingSystem`,
`dNSHostName`, and `servicePrincipalName` — this is the same view a Windows
admin sees in ADUC's "Computers" container. Understanding what a domain join
actually creates in the directory reinforces that it's not magic.

**What this lab teaches:**
- Domain join is what makes a machine trust AD for authentication
- `realmd` automates what used to be 15 manual config file edits
- sssd caches credentials locally — users can log in even if AD is temporarily unreachable
- Computer accounts in AD are how the domain tracks joined machines
- PAM + NSS + sssd is the Linux equivalent of Windows domain authentication

**Experiments:**
- Stop the dc1 container, try logging in with cached credentials — it works
- Clear the sssd cache (`sss_cache -E`), stop dc1, try again — it fails
- Create a second domain admin, delegate OU-level join permissions
- Check `journalctl -u sssd` to understand the LDAP/Kerberos conversation during login
- In LAM, move a computer object between OUs and verify GPO targeting changes (preview of Lab 08)

---

### Lab 05 — DNS Deep Dive

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `dns1` | `ubuntu/bind9:latest` | `10.100.1.40` | Recursive resolver + conditional forwarder |

**What is pre-built:**
- BIND9 installed and running with an empty config
- Samba DNS on dc1 already authoritative for `lab.corp`

**What the student configures:**
1. Configure BIND9 as a recursive resolver for internet queries
2. Add a conditional forwarder: all `lab.corp` queries forward to `10.100.1.10` (dc1)
3. Create a split-horizon setup:
   - Internal zone `apps.lab.corp` resolves `portal.apps.lab.corp` → `10.100.2.50`
   - External view of `apps.lab.corp` resolves the same name → `203.0.113.50` (simulated)
4. Switch workstations to use `dns1` as primary DNS (with dc1 as fallback)
5. Verify recursive resolution: `dig @10.100.1.40 google.com`
6. Verify conditional forwarding: `dig @10.100.1.40 dc1.lab.corp`
7. Verify split-horizon: queries from internal network get internal IPs
8. Add a reverse zone (PTR records) for `10.100.1.0/24`

**Verification commands:**
```bash
# Recursive resolution
dig @10.100.1.40 google.com A +short

# Conditional forwarding to AD
dig @10.100.1.40 _ldap._tcp.lab.corp SRV
dig @10.100.1.40 dc1.lab.corp A

# Split horizon
dig @10.100.1.40 portal.apps.lab.corp A   # from internal → 10.100.2.50

# Reverse DNS
dig @10.100.1.40 -x 10.100.1.10           # → dc1.lab.corp

# DNSSEC validation (if enabled)
dig @10.100.1.40 google.com +dnssec
```

**What this lab teaches:**
- Enterprise DNS is layered: AD DNS handles the domain, BIND handles everything else
- Conditional forwarding is how you glue AD DNS into a larger DNS hierarchy
- Split-horizon DNS is how enterprises serve different answers to internal vs external clients
- Reverse DNS (PTR) matters for mail delivery, logging, and troubleshooting
- `dig +trace` shows the full resolution chain — essential debugging tool

**Experiments:**
- Break the conditional forwarder and watch domain logins fail (they depend on DNS SRV records)
- Enable BIND query logging and trace exactly what queries a domain join generates
- Create a CNAME loop and observe the behavior
- Add response rate limiting (RRL) to BIND and test its effect

---

### Lab 06 — DHCP & Dynamic DNS

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `dhcp1` | `ubuntu:22.04` + kea | `10.100.1.50` | ISC Kea DHCP server |
| `client1` | `workstation:local` | DHCP | Unjoined DHCP client |
| `client2` | `workstation:local` | DHCP | Unjoined DHCP client |

**What is pre-built:**
- Kea DHCP installed but not configured
- Kea DDNS hook library available
- client1/client2 configured to request DHCP on startup

**What the student configures:**
1. Write `kea-dhcp4.conf`: pool `10.100.10.100-10.100.10.200`, lease time 600s,
   options: DNS=10.100.1.40, NTP=10.100.1.20, domain=lab.corp
2. Configure Kea DDNS (`kea-dhcp-ddns.conf`): forward zone `lab.corp` updates
   sent to Samba DNS on dc1 using TSIG key
3. Generate a TSIG key on dc1: `samba-tool dns zoneoption` or `tsig-keygen`
4. Start Kea, release/renew on client1:
   `dhclient -r eth0 && dhclient -v eth0`
5. Verify client1 got an address in the correct range
6. Verify DDNS: `dig @10.100.1.10 client1.lab.corp A` should return client1's
   DHCP address
7. Wait for lease expiry (600s), verify the DNS record is cleaned up
8. Configure DHCP reservations for known MAC addresses

**Verification commands:**
```bash
# On client
ip addr show eth0
cat /etc/resolv.conf

# DDNS verification
dig @10.100.1.10 client1.lab.corp A
dig @10.100.1.10 client2.lab.corp A

# Lease database
cat /var/lib/kea/kea-leases4.csv

# DHCP server logs
journalctl -u kea-dhcp4 --no-pager -n 50
```

**What this lab teaches:**
- DHCP doesn't just hand out IPs — it configures DNS servers, NTP, domain name, gateways
- Dynamic DNS is how DHCP-assigned hosts become resolvable by name automatically
- TSIG keys authenticate DDNS updates so random hosts can't poison your DNS
- Lease management matters: short leases = more DDNS churn, long leases = stale records
- DHCP reservations bridge the gap between static and dynamic addressing

**Experiments:**
- Configure a DHCP scope with no available addresses and watch the DHCPNAK
- Send a DDNS update without the TSIG key — observe the rejection
- Set up a DHCP failover pair (Kea supports hot-standby)
- Capture the DORA exchange with tcpdump and trace each packet

---

### Lab 07 — File Shares & ACLs

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `fs1` | `samba-ad:local` (member server mode) | `10.100.2.10` | Samba file server |

**What is pre-built:**
- Samba installed as a domain member (not a DC)
- Shared directories created: `/srv/shares/engineering`, `/srv/shares/finance`,
  `/srv/shares/public`
- fs1 already joined to the domain

**What the student configures:**
1. Create AD groups: `engineering`, `finance`, `all-staff`
2. Create users: alice (engineering), bob (finance), charlie (all-staff)
3. Configure Samba shares in `smb.conf`:
   - `[engineering]` — read/write for engineering group only
   - `[finance]` — read/write for finance group only
   - `[public]` — read for all-staff, write for no one (read-only)
4. Set POSIX ACLs on the directories to match:
   `setfacl -m g:engineering:rwx /srv/shares/engineering`
5. From ws1 as alice: `smbclient //fs1.lab.corp/engineering -k` — create a file
6. From ws1 as bob: try to access engineering share — should be denied
7. From ws1 as bob: access finance share — should work
8. Test CIFS mount: `mount -t cifs //fs1.lab.corp/engineering /mnt -o sec=krb5`

**Verification commands:**
```bash
# List shares
smbclient -L //fs1.lab.corp -k

# Access with Kerberos
smbclient //fs1.lab.corp/engineering -k -c "ls; put testfile.txt"

# CIFS mount
mount -t cifs //fs1.lab.corp/engineering /mnt -o sec=krb5,cruid=$(id -u)
ls /mnt/

# Check effective permissions
smbcacls //fs1.lab.corp/engineering / -k

# Audit who accessed what
grep "smbd_audit" /var/log/samba/log.smbd
```

**What this lab teaches:**
- File shares are the oldest and most universal enterprise service
- Samba integrates with AD for authentication (Kerberos) AND authorization (group ACLs)
- POSIX ACLs and Windows ACLs are different systems — Samba bridges them
- `sec=krb5` mount option means the file server never sees the user's password
- Access auditing on shares is how you answer "who deleted that file?"

**Experiments:**
- Enable Samba audit logging (`vfs objects = full_audit`) and trace file operations
- Create a nested permission structure and test inheritance
- Try accessing shares with NTLM auth (`-U alice%password`) vs Kerberos (`-k`) — compare
- Set a quota on a share directory and test enforcement

---

### Lab 08 — Group Policy & Configuration Management

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `ansible1` | `ubuntu:22.04` + ansible | `10.100.3.10` | Ansible control node |

**What is pre-built:**
- Ansible installed with Kerberos auth modules
- SSH keys distributed to all workstations
- Samba GPO tools available on dc1

**Part A — Samba Group Policy (30 min):**
1. Create a GPO: `samba-tool gpo create "Default Workstation Policy"`
2. Link it to the Workstations OU:
   `samba-tool gpo setlink "OU=Workstations,DC=lab,DC=corp" <GPO-GUID>`
3. Set a policy (password complexity, account lockout):
   `samba-tool gpo manage security set <GPO-GUID> ...`
4. On ws1, apply: `samba-gpupdate --force`
5. Verify the policy took effect

**Part B — Ansible for Linux config management (1.5-2 hours):**

This is the core of the lab. Samba GPO is limited on Linux; Ansible is how
enterprises actually manage Linux hosts at scale.

1. Configure Ansible inventory using AD groups as host groups (dynamic inventory
   via LDAP plugin or static mapping)
2. Write playbooks:
   - `enforce-ntp.yml` — ensure all hosts point at ntp1, chrony is running
   - `enforce-ssh-banner.yml` — deploy login banner to all workstations
   - `enforce-resolved.yml` — ensure DNS config points at dns1
   - `harden-sshd.yml` — disable root login, enforce key auth
3. Run playbooks: `ansible-playbook -i inventory.yml enforce-ntp.yml`
4. Verify idempotency: run the same playbook twice, second run shows no changes
5. Create a "drift detection" playbook that checks current state and reports
   non-compliant hosts

**Verification commands:**
```bash
# Samba GPO
samba-tool gpo listall
samba-tool gpo getlink "OU=Workstations,DC=lab,DC=corp"

# Ansible
ansible all -i inventory.yml -m ping
ansible-playbook enforce-ntp.yml --check --diff   # dry run
ansible-playbook enforce-ntp.yml                   # apply
ansible-playbook enforce-ntp.yml                   # idempotent (0 changed)
```

**What this lab teaches:**
- Group Policy is how Windows enterprises enforce configuration — but it's limited on Linux
- Ansible fills the same role for Linux: desired-state configuration at scale
- Idempotency is the key principle: playbooks describe what SHOULD be, not steps to GET there
- Configuration drift is the enemy — detection is as important as enforcement
- Real enterprises use both GPO and Ansible (or Puppet/Chef) side by side

**Experiments:**
- Manually change the NTP config on ws1, re-run the playbook, verify it's corrected
- Write a playbook that creates AD users via `samba-tool` (infrastructure-as-code)
- Set up Ansible Vault to encrypt the AD admin password in the inventory

---

### Lab 09 — Email Gateway

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `mail1` | `ghcr.io/docker-mailserver/docker-mailserver:latest` | `10.100.2.20` | Postfix + Dovecot mail server |

**What is pre-built:**
- docker-mailserver container running with basic config
- MX record for `lab.corp` pointed at mail1
- TLS certificate from ca1 (Lab 03) pre-installed

**What the student configures:**
1. Configure LDAP authentication: point docker-mailserver at dc1 for user lookups
   (`LDAP_SERVER_HOST=ldap://dc1.lab.corp`, `LDAP_SEARCH_BASE=DC=lab,DC=corp`,
   `LDAP_BIND_DN`, `LDAP_BIND_PW`)
2. Add MX record to Samba DNS: `samba-tool dns add dc1.lab.corp lab.corp @ MX "mail1.lab.corp 10"`
3. Test sending mail between AD users:
   ```bash
   # From ws1 as alice
   swaks --to bob@lab.corp --from alice@lab.corp --server mail1.lab.corp
   ```
4. Check bob's inbox via IMAP:
   ```bash
   curl -k imaps://mail1.lab.corp/INBOX -u bob@lab.corp:password
   ```
5. Configure spam filtering basics: enable SpamAssassin, test with GTUBE string
6. Configure DKIM signing and verify outbound signatures
7. Set up mail aliases: `postmaster@lab.corp` → `alice@lab.corp`

**Verification commands:**
```bash
# MX lookup
dig @10.100.1.10 lab.corp MX

# Send test email
swaks --to bob@lab.corp --from alice@lab.corp --server mail1.lab.corp --tls

# Check delivery via IMAP
curl -k imaps://mail1.lab.corp/INBOX -u bob@lab.corp:P@ssw0rd1

# Check mail logs
docker exec mail1 cat /var/log/mail/mail.log | tail -20

# Test spam filter (GTUBE = guaranteed spam test)
swaks --to bob@lab.corp --from spammer@external.com --server mail1.lab.corp \
  --body "XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X"
```

**What this lab teaches:**
- Email is SMTP (sending) + IMAP/POP3 (receiving) — two separate protocols
- LDAP integration means AD users automatically have mailboxes — no separate account creation
- MX records tell the world where to deliver mail for your domain
- TLS on SMTP (STARTTLS) and IMAPS are non-negotiable in a real enterprise
- Spam filtering, DKIM, and SPF are defense layers every mail admin must understand

**Experiments:**
- Send mail without TLS, capture with tcpdump, read the plaintext — see why TLS matters
- Misconfigure the LDAP bind DN and watch authentication fail
- Set up a mail relay scenario: external mail → mail1 → internal delivery
- Add SPF and DMARC DNS records and test with an external validator

---

### Lab 10 — SSO & Federation (ADFS Equivalent)

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `keycloak` | `quay.io/keycloak/keycloak:latest` | `10.100.2.30` | Identity provider (IdP) |
| `sample-app` | Custom Flask app | `10.100.2.31` | OIDC-protected web app |
| `postgres-kc` | `postgres:15` | `10.100.2.32` | Keycloak database |

**What is pre-built:**
- Keycloak running with an empty realm
- Sample Flask app with OIDC middleware (python-jose / authlib) but no IdP configured
- TLS cert from ca1 installed on Keycloak

**What the student configures:**
1. Create a `lab-corp` realm in Keycloak admin console (https://keycloak.lab.corp:8443)
2. Configure LDAP User Federation:
   - Connection URL: `ldap://dc1.lab.corp`
   - Users DN: `CN=Users,DC=lab,DC=corp`
   - Bind DN: service account in AD
   - Sync users: click "Sync all users" — AD users appear in Keycloak
3. Create an OIDC client for the sample app:
   - Client ID: `sample-app`
   - Redirect URI: `https://sample-app.lab.corp:5000/callback`
   - Client secret generated by Keycloak
4. Configure the sample app with the client ID, secret, and Keycloak discovery URL
5. Access `https://sample-app.lab.corp:5000` — get redirected to Keycloak login —
   log in as alice — get redirected back with a token
6. Enable TOTP MFA:
   - In Keycloak, set "OTP Policy" to required for the realm
   - Log in as alice — Keycloak prompts for TOTP setup
   - Use a TOTP app (or `oathtool` on the CLI) to generate codes
7. Test SAML (optional): create a SAML client alongside OIDC, compare the flows

**Verification commands:**
```bash
# Keycloak health
curl -k https://keycloak.lab.corp:8443/health

# OIDC discovery
curl -k https://keycloak.lab.corp:8443/realms/lab-corp/.well-known/openid-configuration | jq

# Get a token via Resource Owner Password Grant (for testing)
curl -k -X POST https://keycloak.lab.corp:8443/realms/lab-corp/protocol/openid-connect/token \
  -d "client_id=sample-app" -d "client_secret=<secret>" \
  -d "username=alice" -d "password=P@ssw0rd1" -d "grant_type=password"

# Decode the JWT
echo "<access_token>" | cut -d. -f2 | base64 -d | jq

# Verify TOTP
oathtool --totp -b <secret-from-qr>
```

**What this lab teaches:**
- SSO means "authenticate once, access many apps" — Keycloak is the open-source ADFS
- OIDC is the modern standard (JSON/REST); SAML is the legacy standard (XML/POST)
- User federation means Keycloak doesn't store passwords — AD does. Keycloak is a broker.
- JWTs contain claims (user identity, group membership) that apps consume directly
- MFA adds a second factor — Keycloak handles enrollment, not the app
- The OIDC Authorization Code flow: app → IdP → login → code → token → app

**Experiments:**
- Decode the JWT and find the group memberships — map AD groups to Keycloak roles
- Disable the LDAP federation and watch login break (Keycloak can't validate passwords)
- Configure a second app and verify SSO works (log in once, access both)
- Set up client-certificate authentication as an alternative to password+MFA

---

### Lab 11 — Web Proxy & Filtering

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `proxy1` | `squid-ad:local` (custom) | `10.100.2.40` | Squid proxy with AD auth |
| `webserver1` | `nginx:alpine` | `10.100.2.41` | Internal web server |
| `webserver2` | `nginx:alpine` | `10.100.2.42` | "Blocked" web server |

**Custom image: `squid-ad:local`**
- Base: `ubuntu:22.04`
- Packages: `squid`, `krb5-user`, `libsasl2-modules-gssapi-mit`, `msktutil`
- Joined to lab.corp domain for Kerberos negotiate auth

**What is pre-built:**
- Squid installed and running with basic config (no auth)
- Two web servers serving distinct pages ("allowed-site" and "blocked-site")
- Workstations' HTTP_PROXY not yet configured

**What the student configures:**
1. Generate a keytab for Squid: `msktutil -c -s HTTP/proxy1.lab.corp -k /etc/squid/squid.keytab`
2. Configure Squid for Kerberos Negotiate authentication:
   ```
   auth_param negotiate program /usr/lib/squid/negotiate_kerberos_auth -s HTTP/proxy1.lab.corp
   auth_param negotiate children 10
   ```
3. Create ACLs based on AD group membership:
   - `engineering` group → full access
   - `finance` group → block `webserver2` (simulate blocking a category)
4. Set `http_proxy=http://proxy1.lab.corp:3128` on workstations
5. From ws1 as alice (engineering): access both web servers — both work
6. From ws1 as bob (finance): access webserver2 — blocked with a deny page
7. Enable Squid access logging, review who accessed what:
   `tail -f /var/log/squid/access.log`

**Verification commands:**
```bash
# Test proxy without auth
curl -x http://proxy1.lab.corp:3128 http://webserver1.lab.corp

# Test with Kerberos auth
curl -x http://proxy1.lab.corp:3128 --negotiate -u : http://webserver1.lab.corp

# Verify blocking
curl -x http://proxy1.lab.corp:3128 --negotiate -u : http://webserver2.lab.corp
# → 403 Forbidden

# Check Squid logs
tail -f /var/log/squid/access.log
# Shows: timestamp, user (alice@LAB.CORP), URL, action (TCP_DENIED/200)

# Verify Kerberos ticket for Squid
klist   # should show HTTP/proxy1.lab.corp service ticket
```

**What this lab teaches:**
- Enterprise web proxies serve three purposes: access control, logging, and caching
- Kerberos negotiate auth means transparent authentication — no password prompts
- AD group-based ACLs let you enforce different policies for different departments
- Access logs answer "who went where and when" — compliance and forensics
- SSL/TLS bump (concept discussion, not implemented) is how proxies inspect HTTPS

**Experiments:**
- Remove the proxy setting and access the blocked site directly — it works (proxy only filters if traffic goes through it)
- Configure Squid to cache responses, load a page twice, check `TCP_HIT` in logs
- Add a PAC (Proxy Auto-Config) file and serve it via DHCP option 252
- Discuss (don't implement) SSL bump: why it's controversial, how it works, cert implications

---

### Lab 12 — RADIUS & AD Integration

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `radius1` | `freeradius-ad:local` (custom) | `10.100.20.10` | FreeRADIUS server |
| `nas1` | `workstation:local` | `10.100.20.11` | Simulated network device (NAS) |
| `supplicant1` | `workstation:local` | `10.100.20.12` | Wired client (EAP-PEAP) |
| `supplicant2` | `workstation:local` | `10.100.20.13` | Wired client (EAP-TLS) |

**Custom image: `freeradius-ad:local`**
- Base: `ubuntu:22.04`
- Packages: `freeradius`, `freeradius-ldap`, `freeradius-krb5`, `freeradius-utils`,
  `krb5-user`, `ldap-utils`
- Joined to lab.corp domain

**What is pre-built:**
- FreeRADIUS installed with default config
- Client certificates from ca1 available for EAP-TLS
- `nas1` has `radtest` and `eapol_test` installed

**What the student configures:**
1. Configure FreeRADIUS LDAP module to authenticate against AD:
   ```
   ldap {
       server = "dc1.lab.corp"
       base_dn = "DC=lab,DC=corp"
       identity = "CN=radius-svc,CN=Users,DC=lab,DC=corp"
       password = <service-account-password>
   }
   ```
2. Create the RADIUS service account in AD:
   `samba-tool user create radius-svc --description="RADIUS service account"`
3. Configure EAP: enable PEAP/MSCHAPv2 and EAP-TLS in `mods-available/eap`
4. Install the CA certificate and server certificate (from Lab 03) for EAP-TLS
5. Add NAS client in `clients.conf`:
   ```
   client nas1 {
       ipaddr = 10.100.20.11
       secret = testing123
   }
   ```
6. Test PEAP auth: `radtest alice P@ssw0rd1 10.100.20.10 0 testing123`
7. Test EAP-TLS with `eapol_test`:
   ```bash
   eapol_test -c /etc/eapol_test/eap-tls.conf -a 10.100.20.10 -s testing123
   ```
8. Configure VLAN assignment based on AD group membership:
   - engineering → VLAN 10
   - finance → VLAN 20
   - Use RADIUS `Tunnel-Private-Group-Id` attribute
9. Verify VLAN attributes in Access-Accept:
   `radtest` with `-x` debug shows the reply attributes

**Verification commands:**
```bash
# Simple PAP test
radtest alice P@ssw0rd1 10.100.20.10 0 testing123

# Debug mode (see full exchange)
docker exec radius1 freeradius -X &
radtest alice P@ssw0rd1 10.100.20.10 0 testing123

# EAP-TLS test
eapol_test -c eap-tls.conf -a 10.100.20.10 -s testing123

# Check VLAN assignment in reply
radtest alice P@ssw0rd1 10.100.20.10 0 testing123 | grep Tunnel

# RADIUS accounting test
radtest -t acct alice P@ssw0rd1 10.100.20.10 0 testing123
```

**What this lab teaches:**
- RADIUS is how network devices (switches, APs, VPN) authenticate users against AD
- The NAS (network access server) is the middleman: client → NAS → RADIUS → AD
- PEAP wraps MSCHAPv2 in a TLS tunnel — password-based but encrypted
- EAP-TLS uses certificates for both sides — no passwords at all (strongest option)
- VLAN assignment via RADIUS is how enterprises enforce network segmentation dynamically
- RADIUS accounting logs who connected, from where, and for how long

**Experiments:**
- Capture the RADIUS exchange with tcpdump on port 1812 — open in Wireshark with shared secret
- Disable the LDAP module and try local user auth instead — compare the configurations
- Simulate a wrong shared secret between NAS and RADIUS — observe the silent failure
- Add RADIUS accounting and check the accounting log for session details
- Test what happens when AD is unreachable — does RADIUS fail open or closed?

---

### Lab 13 — Monitoring & Alerting

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `prometheus` | `prom/prometheus:latest` | `10.100.3.20` | Metrics collection |
| `grafana` | `grafana/grafana:latest` | `10.100.3.21` | Dashboards |
| `alertmanager` | `prom/alertmanager:latest` | `10.100.3.22` | Alert routing |
| `node-exporter` | (sidecar on each host) | various | Host metrics |
| `blackbox` | `prom/blackbox-exporter:latest` | `10.100.3.23` | Probe endpoints |

**What is pre-built:**
- Prometheus running with an empty scrape config
- Grafana running with no datasources
- node-exporter sidecar on dc1, mail1, keycloak, proxy1
- blackbox-exporter for HTTP/TCP/ICMP probes

**What the student configures:**
1. Configure Prometheus scrape targets:
   - node-exporter on all key hosts (CPU, memory, disk, network)
   - blackbox probes: LDAP (tcp:389), LDAPS (tcp:636), DNS (dns query),
     SMTP (tcp:25), HTTPS (https on Keycloak, proxy)
   - Kea DHCP stats endpoint (if available)
2. Add Grafana datasource pointing at Prometheus
3. Build a "Lab Corp Overview" dashboard:
   - Host health (CPU, memory, disk per node)
   - Service availability (up/down for each critical service)
   - DNS query latency
   - LDAP connection count
4. Configure alert rules:
   - `dc1` down for >1 minute → critical
   - Disk usage >80% on any host → warning
   - DNS query latency >500ms → warning
   - TLS cert expiring within 7 days → warning
5. Configure Alertmanager to send alerts (to a local webhook or log file)
6. Trigger an alert: stop dc1, watch the alert fire in Alertmanager

**Verification commands:**
```bash
# Prometheus targets
curl http://10.100.3.20:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Query metrics
curl 'http://10.100.3.20:9090/api/v1/query?query=up' | jq

# Grafana
# → browser: http://10.100.3.21:3000 (admin/admin)

# Trigger alert
docker stop dc1
# Wait 1 min, check:
curl http://10.100.3.22:9093/api/v2/alerts | jq
```

**What this lab teaches:**
- Monitoring answers "is it working?" before users report it broken
- Prometheus pull-based model: the monitoring server scrapes targets, not the other way around
- Blackbox probes test services the way users experience them (can I connect? does it respond?)
- Alerting is useless without routing and escalation — Alertmanager handles this
- Dashboards are for humans; alerts are for incidents — you need both
- TLS certificate expiry monitoring prevents the most common enterprise outage

**Experiments:**
- Create a recording rule to pre-compute "service uptime percentage over 24h"
- Add a Loki instance for log aggregation alongside metrics
- Set up a PagerDuty-like webhook receiver and test the full alert pipeline
- Build a dashboard that shows the Kerberos-dependent services and their health together

---

### Lab 14 — SIEM & Security Logging

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `wazuh-manager` | `wazuh/wazuh-manager:latest` | `10.100.3.30` | Wazuh SIEM manager |
| `wazuh-dashboard` | `wazuh/wazuh-dashboard:latest` | `10.100.3.31` | Wazuh web UI |
| `wazuh-indexer` | `wazuh/wazuh-indexer:latest` | `10.100.3.32` | OpenSearch index |

**Existing containers modified:** Wazuh agents installed on dc1, mail1, keycloak, ws1

**What is pre-built:**
- Wazuh stack running (manager + indexer + dashboard)
- Agent packages available on workstations
- Samba audit logging enabled on dc1

**What the student configures:**
1. Install Wazuh agent on dc1:
   ```bash
   dpkg -i wazuh-agent.deb
   sed -i 's/MANAGER_IP/10.100.3.30/' /var/ossec/etc/ossec.conf
   systemctl start wazuh-agent
   ```
2. Register agents with the manager:
   `/var/ossec/bin/agent-auth -m 10.100.3.30`
3. Repeat for mail1, keycloak, ws1
4. Configure Samba audit log forwarding: add Samba log path to agent's
   `localfile` config so AD authentication events flow to Wazuh
5. Generate security events:
   - Failed login attempts: `kinit baduser@LAB.CORP` (5 times)
   - Successful login after failures
   - File access on fs1
   - SSH login to ws1
6. View events in Wazuh dashboard:
   - Filter by agent, rule level, rule group
   - Find the brute-force detection rule triggering on 5+ failed logins
7. Create a custom rule: alert when a new user is created in AD
   (match on `samba-tool user create` in audit log)
8. Configure active response: block an IP after 10 failed SSH attempts

**Verification commands:**
```bash
# Agent status
/var/ossec/bin/agent_control -l

# Check manager received events
curl -k -u admin:admin https://10.100.3.30:55000/agents?pretty

# Generate events
for i in $(seq 1 5); do kinit baduser@LAB.CORP <<< "wrongpass" 2>/dev/null; done

# Check alerts
curl -k -u admin:admin 'https://10.100.3.30:55000/alerts?pretty&limit=10'

# Wazuh dashboard → browser: https://10.100.3.31
```

**What this lab teaches:**
- A SIEM aggregates logs from everywhere and correlates them into security alerts
- Brute-force detection is rule-based: N failed attempts in M seconds → alert
- AD audit logs are the single most valuable data source in enterprise security
- Active response automates incident containment (block, isolate, disable)
- The difference between monitoring (Lab 13) and SIEM: monitoring = availability, SIEM = security
- Log sources you should always collect: AD auth, firewall, mail, DNS queries, endpoint

**Experiments:**
- Create a correlation rule: failed VPN auth (RADIUS) + failed AD login from same source = alert
- Configure file integrity monitoring (FIM) on `/etc/` across all agents
- Generate a rootkit-like event (modify a system binary) and verify Wazuh detects it
- Export a report of all security events in the last hour — practice incident documentation

---

### Lab 15 — Backup & Disaster Recovery

**Duration:** 2-3 hours

**New containers:**
| Name | Image | IP | Role |
|------|-------|----|------|
| `backup1` | `ubuntu:22.04` + borgbackup | `10.100.3.40` | Backup server |

**What is pre-built:**
- BorgBackup installed on backup1 and all key service nodes
- SSH keys from backup1 to all service nodes
- Backup repositories initialized

**What the student configures:**
1. Initialize Borg repositories:
   ```bash
   borg init --encryption=repokey ssh://backup1/srv/backups/dc1
   borg init --encryption=repokey ssh://backup1/srv/backups/mail1
   borg init --encryption=repokey ssh://backup1/srv/backups/ca1
   ```
2. Create backup scripts for each service:
   - **AD (dc1):** Back up Samba's `private/`, `etc/`, and `sysvol/` directories.
     Run `samba-tool dbcheck` before backup to verify DB integrity.
   - **CA (ca1):** Back up step-ca's `$(step path)` directory (contains root key!)
   - **Mail (mail1):** Back up `/var/mail/` and Postfix config
   - **Keycloak (keycloak):** `pg_dump` of the Keycloak PostgreSQL database
3. Run the backups: `borg create ssh://backup1/srv/backups/dc1::$(date +%Y%m%d) /var/lib/samba`
4. Verify backup: `borg list ssh://backup1/srv/backups/dc1`, `borg info`
5. **Disaster scenario — AD recovery:**
   - Stop dc1
   - Delete Samba's database: `rm -rf /var/lib/samba/private/sam.ldb*`
   - Restore from backup: `borg extract ssh://backup1/srv/backups/dc1::latest`
   - Start dc1, verify domain functionality: `samba-tool user list`, `kinit alice@LAB.CORP`
6. **Disaster scenario — CA recovery:**
   - Delete the CA's private key
   - Attempt to issue a certificate — fails
   - Restore from backup, issue a certificate — works
7. Configure scheduled backups via cron:
   `0 2 * * * /usr/local/bin/backup-all.sh`
8. Set retention policy: keep 7 daily, 4 weekly, 6 monthly

**Verification commands:**
```bash
# List backups
borg list ssh://backup1/srv/backups/dc1

# Backup details
borg info ssh://backup1/srv/backups/dc1::latest

# Dry-run restore
borg extract --dry-run ssh://backup1/srv/backups/dc1::latest

# Verify AD after restore
samba-tool user list
samba-tool dbcheck
kinit alice@LAB.CORP
```

**What this lab teaches:**
- Backups aren't real until you've tested a restore — this lab forces you to restore
- AD is the most critical service: if AD is gone, nothing else works (no auth, no DNS, no GPO)
- CA backup includes private keys — these must be encrypted and access-controlled
- Database backups (pg_dump) are application-consistent; file copies may not be
- Retention policies balance storage cost against recovery point objectives (RPO)
- The 3-2-1 rule: 3 copies, 2 media types, 1 offsite (discussed conceptually)

**Experiments:**
- Test point-in-time recovery: create a user, take backup, delete user, restore, verify user exists
- Encrypt a backup repository with a passphrase, then try restoring without it
- Measure backup size with and without deduplication (Borg deduplicates by default)
- Simulate a "forgot the encryption key" scenario — discuss key escrow

---

### Lab 16 — Capstone: The Mini Enterprise

**Duration:** 3-4 hours

**Containers:** All services from Labs 1-15 running simultaneously.

**docker-compose.yml:** A single unified compose file that brings up the entire
`lab.corp` infrastructure.

**The lab has three parts:**

**Part A — New Employee Onboarding (45 min):**

Given: a new employee "Dave" is joining the engineering team. Provision him end-to-end:

1. Create AD account with correct OU and group membership
2. Verify NTP sync on his workstation
3. Join his workstation to the domain
4. Verify he can log in with AD credentials
5. Verify he can access the engineering file share (and NOT finance)
6. Verify he can send/receive email as dave@lab.corp
7. Verify he can log into the sample app via Keycloak SSO
8. Verify he gets VLAN 10 via RADIUS when authenticating to the network
9. Verify the web proxy allows his traffic and logs it
10. Verify his workstation appears in monitoring and SIEM

**Checklist:**
```
[ ] AD account created in correct OU
[ ] Member of engineering group
[ ] Visible in LAM with correct attributes and group membership
[ ] Workstation domain-joined, appears in AD computer list (verify in LAM)
[ ] Can kinit and get TGT
[ ] File share access: engineering=yes, finance=no
[ ] Email send/receive works
[ ] SSO login works, JWT contains engineering group
[ ] RADIUS returns VLAN 10
[ ] Proxy logs show dave's browsing
[ ] Wazuh agent running, events flowing
[ ] Monitoring shows workstation metrics
```

**Part B — Troubleshooting (1-1.5 hours):**

Three services are deliberately broken. The student must diagnose and fix each:

1. **Break script 1 — DNS:** The conditional forwarder on dns1 is pointed at
   the wrong IP. Domain logins fail with "unable to resolve dc1.lab.corp."
   Student must check DNS resolution, find the bad forwarder, fix it.

2. **Break script 2 — Kerberos:** The clock on dc1 has been skewed by 10 minutes.
   Kerberos auth fails everywhere with "Clock skew too great." Student must
   identify the time issue, fix dc1's clock, and verify auth recovers.

3. **Break script 3 — Email:** The LDAP bind password in docker-mailserver's
   config has been changed to an incorrect value. Users can't authenticate to
   IMAP. Student must check mail logs, identify the LDAP bind failure, fix
   the password, and verify mail works.

**Part C — Architecture Documentation (30 min):**

The student draws a diagram of the complete `lab.corp` infrastructure showing:
- All services and their IP addresses
- Authentication flows (which services talk to AD and how)
- DNS resolution chain
- Certificate trust chain
- Monitoring/SIEM data flows

This is a paper exercise — the goal is to verify the student understands
how everything connects, not just how to configure each piece individually.

**What this lab teaches:**
- Enterprise IT is a system of interdependencies, not isolated services
- Onboarding exercises the entire stack end-to-end
- Troubleshooting requires understanding the dependency chain (DNS → Kerberos → everything else)
- Documentation and architecture diagrams are deliverables, not afterthoughts

---

## Container resource estimates

| Service | Memory | CPU | Disk |
|---------|--------|-----|------|
| Samba AD DC | 512MB | 0.5 | 200MB |
| step-ca | 128MB | 0.25 | 50MB |
| BIND9 | 128MB | 0.25 | 20MB |
| ISC Kea | 128MB | 0.25 | 20MB |
| chrony | 64MB | 0.1 | 10MB |
| docker-mailserver | 512MB | 0.5 | 500MB |
| Keycloak + Postgres | 768MB | 0.5 | 200MB |
| Squid | 256MB | 0.25 | 100MB |
| FreeRADIUS | 128MB | 0.25 | 50MB |
| Prometheus | 256MB | 0.25 | 200MB |
| Grafana | 256MB | 0.25 | 100MB |
| Wazuh stack (3 containers) | 2GB | 1.0 | 1GB |
| BorgBackup server | 128MB | 0.25 | varies |
| Workstations (x3) | 256MB each | 0.25 each | 50MB each |
| Samba file server | 256MB | 0.25 | 100MB |
| Ansible control | 256MB | 0.25 | 100MB |
| **Total (all labs running)** | **~7GB** | **~5 cores** | **~3GB** |

Individual labs (phases 1-3) need 2-4GB. Only the capstone requires the full stack.

---

## Prerequisites

- Docker Engine 24+ and Docker Compose v2
- 8GB RAM minimum (16GB recommended for capstone)
- 20GB free disk space
- Internet access for pulling images (first run only)
- A TOTP authenticator app (for Lab 10 MFA)

---

## Docs integration (mkdocs)

Add a new top-level nav section in `mkdocs.yml`:

```yaml
nav:
  - Home: index.md
  - Getting Started: getting-started.md
  # ... existing networking labs ...
  - Enterprise IT 101:
    - tracks/enterprise-it-101/index.md
    - "01 Active Directory": tracks/enterprise-it-101/01-active-directory.md
    - "02 NTP & Time": tracks/enterprise-it-101/02-ntp-time-services.md
    - "03 Certificate Authority": tracks/enterprise-it-101/03-certificate-authority.md
    - "04 Domain Join": tracks/enterprise-it-101/04-domain-join.md
    - "05 DNS Deep Dive": tracks/enterprise-it-101/05-dns-deep-dive.md
    - "06 DHCP & DDNS": tracks/enterprise-it-101/06-dhcp-dynamic-dns.md
    - "07 File Shares": tracks/enterprise-it-101/07-file-shares.md
    - "08 Group Policy & Config Mgmt": tracks/enterprise-it-101/08-group-policy.md
    - "09 Email Gateway": tracks/enterprise-it-101/09-email-gateway.md
    - "10 SSO & Federation": tracks/enterprise-it-101/10-sso-federation.md
    - "11 Web Proxy": tracks/enterprise-it-101/11-web-proxy.md
    - "12 RADIUS": tracks/enterprise-it-101/12-radius.md
    - "13 Monitoring": tracks/enterprise-it-101/13-monitoring.md
    - "14 SIEM & Logging": tracks/enterprise-it-101/14-siem-logging.md
    - "15 Backup & Recovery": tracks/enterprise-it-101/15-backup-recovery.md
    - "16 Capstone": tracks/enterprise-it-101/16-capstone.md
```

Each doc page will use `include-markdown` to pull the lab's `README.md` so the
source of truth stays in the lab directory.

---

## Open design decisions (to resolve during implementation)

1. **Samba AD provisioning**: pre-provision in the Docker entrypoint (faster
   startup, less student work) vs. have the student run `samba-tool domain
   provision` manually (more educational). **Current choice:** student runs it
   manually in Lab 01, then it's baked into the entrypoint for Labs 02+.

2. **Compose strategy**: one growing compose file vs. per-lab overrides.
   **Current choice:** base compose + per-lab overrides, merged with
   `docker compose -f base/docker-compose.yml -f labs/05-dns-deep-dive/docker-compose.override.yml up`.

3. **Image builds**: pre-built images on a registry vs. local Dockerfile builds.
   **Current choice:** local builds only (no registry dependency), with a
   `build-all.sh` script.

4. **Wazuh resource usage**: The Wazuh stack is heavy (~2GB RAM). Consider
   offering a "lite" alternative using just rsyslog + a simple log viewer for
   resource-constrained machines.

5. **Lab interdependency management**: If a student wants to jump to Lab 10 without
   doing Labs 5-9, they need the foundation (Labs 1-4) but could skip the
   middle. Consider providing "checkpoint" compose files that include all
   services up to a given point, pre-configured.
