---
title: "12 — RADIUS & AD Integration"
---

!!! tip "Advanced Services Lab 3 of 3"
    Deploy FreeRADIUS with LDAP authentication against Active Directory, configure EAP-PEAP and EAP-TLS, and assign VLANs based on group membership — how switches and APs authenticate users.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/12-radius/`  
**Requires:** Foundation + Labs 05–11

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `radius1` | `freeradius-ad:local` (custom) | `10.100.20.10` | FreeRADIUS server |
| `nas1` | `workstation:local` | `10.100.20.11` | Simulated network device (NAS) |
| `supplicant1` | `workstation:local` | `10.100.20.12` | Wired client — EAP-PEAP |
| `supplicant2` | `workstation:local` | `10.100.20.13` | Wired client — EAP-TLS |

## What is Pre-Built

- FreeRADIUS installed with default config
- Client certificates from `ca1` available for EAP-TLS
- `nas1` has `radtest` and `eapol_test` installed

## What You Configure

**1. Create the RADIUS service account in AD**

```bash
docker exec dc1 samba-tool user create radius-svc P@ssw0rd1 \
  --description="RADIUS service account"
```

**2. Configure the LDAP module**

In `/etc/freeradius/3.0/mods-available/ldap`:
```
ldap {
    server    = "dc1.lab.corp"
    base_dn   = "DC=lab,DC=corp"
    identity  = "CN=radius-svc,CN=Users,DC=lab,DC=corp"
    password  = "P@ssw0rd1"
    user {
        base_dn = "${..base_dn}"
        filter  = "(sAMAccountName=%{%{Stripped-User-Name}:-%{User-Name}})"
    }
}
```

**3. Configure EAP (PEAP/MSCHAPv2 and EAP-TLS)**

In `mods-available/eap`:
```
eap {
    default_eap_type = peap
    tls-config tls-common {
        private_key_file  = /etc/freeradius/certs/server.key
        certificate_file  = /etc/freeradius/certs/server.crt
        ca_file           = /etc/freeradius/certs/ca.crt
    }
    peap { }
    tls  { }
}
```

**4. Add the NAS client**

In `clients.conf`:
```
client nas1 {
    ipaddr  = 10.100.20.11
    secret  = testing123
    shortname = nas1
}
```

**5. Test PEAP authentication**

```bash
docker exec nas1 radtest alice P@ssw0rd1 10.100.20.10 0 testing123
# Expect: Access-Accept
```

**6. Test EAP-TLS**

```bash
docker exec supplicant2 eapol_test \
  -c /etc/eapol_test/eap-tls.conf \
  -a 10.100.20.10 \
  -s testing123
```

**7. Configure VLAN assignment by group**

In the `post-auth` section of `sites-available/default`:
```
if (&LDAP-Group == "engineering") {
    update reply {
        Tunnel-Type            = VLAN
        Tunnel-Medium-Type     = IEEE-802
        Tunnel-Private-Group-Id = "10"
    }
}
if (&LDAP-Group == "finance") {
    update reply {
        Tunnel-Type            = VLAN
        Tunnel-Medium-Type     = IEEE-802
        Tunnel-Private-Group-Id = "20"
    }
}
```

## Verification Commands

```bash
# Simple PAP test
docker exec nas1 radtest alice P@ssw0rd1 10.100.20.10 0 testing123

# Debug mode (full exchange)
docker exec radius1 freeradius -X &
docker exec nas1 radtest alice P@ssw0rd1 10.100.20.10 0 testing123

# EAP-TLS test
docker exec supplicant2 eapol_test -c eap-tls.conf -a 10.100.20.10 -s testing123

# Check VLAN attributes in the reply
docker exec nas1 radtest alice P@ssw0rd1 10.100.20.10 0 testing123 | grep Tunnel

# RADIUS accounting
docker exec nas1 radtest -t acct alice P@ssw0rd1 10.100.20.10 0 testing123
```

## What This Lab Teaches

- **RADIUS** is how network devices (switches, APs, VPN gateways) authenticate users against AD
- The **NAS** (network access server) is the middleman: client → NAS → RADIUS → AD
- **EAP-PEAP** wraps MSCHAPv2 in a TLS tunnel — password-based but encrypted
- **EAP-TLS** uses certificates for both sides — no passwords, the strongest option
- **VLAN assignment via RADIUS** is how enterprises enforce network segmentation dynamically
- **RADIUS accounting** logs who connected, from where, and for how long

## Experiments

- Capture the RADIUS exchange on port 1812 with tcpdump and open it in Wireshark using the shared secret
- Disable the LDAP module and configure local user auth — compare the complexity
- Use a wrong shared secret between `nas1` and `radius1` and observe the silent failure
- Test what happens when AD is unreachable — does RADIUS fail open or closed?
