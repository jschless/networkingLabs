---
title: "06 — DHCP & Dynamic DNS"
---

!!! tip "Core Services Lab 2 of 5"
    Deploy ISC Kea DHCP and configure it to register client hostnames in Samba DNS automatically via TSIG-authenticated DDNS updates.

**Duration:** 2–3 hours  
**Directory:** `enterprise-it-101/labs/06-dhcp-dynamic-dns/`  
**Requires:** Foundation + Lab 05

## Containers

| Name | Image | IP | Role |
|------|-------|----|------|
| `dhcp1` | `ubuntu:22.04` + Kea | `10.100.1.50` | ISC Kea DHCP server |
| `client1` | `workstation:local` | DHCP | Unjoined DHCP client |
| `client2` | `workstation:local` | DHCP | Unjoined DHCP client |

## What is Pre-Built

- Kea DHCP installed but not configured
- Kea DDNS hook library available
- `client1` and `client2` configured to request DHCP on startup

## What You Configure

**1. Write `kea-dhcp4.conf`**

```json
{
  "Dhcp4": {
    "interfaces-config": { "interfaces": ["eth0"] },
    "subnet4": [{
      "subnet": "10.100.10.0/24",
      "pools": [{ "pool": "10.100.10.100 - 10.100.10.200" }],
      "option-data": [
        { "name": "domain-name-servers", "data": "10.100.1.40" },
        { "name": "ntp-servers",         "data": "10.100.1.20" },
        { "name": "domain-name",         "data": "lab.corp"    }
      ],
      "valid-lifetime": 600
    }]
  }
}
```

**2. Generate a TSIG key on dc1**

```bash
docker exec dc1 samba-tool dns zoneoption \
  lab.corp --option=AllowUpdate:Secure
tsig-keygen dhcp-ddns-key > /etc/kea/dhcp-ddns.key
```

**3. Configure Kea DDNS (`kea-dhcp-ddns.conf`)**

```json
{
  "DhcpDdns": {
    "forward-ddns": {
      "ddns-domains": [{
        "name": "lab.corp.",
        "dns-servers": [{ "ip-address": "10.100.1.10" }],
        "tsig-key-name": "dhcp-ddns-key"
      }]
    }
  }
}
```

**4. Release/renew on a client**

```bash
docker exec -it client1 bash
dhclient -r eth0 && dhclient -v eth0
```

**5. Verify DDNS registration**

```bash
dig @10.100.1.10 client1.lab.corp A
dig @10.100.1.10 client2.lab.corp A
```

## Verification Commands

```bash
# Client address
docker exec client1 ip addr show eth0

# Resolver config pushed by DHCP
docker exec client1 cat /etc/resolv.conf

# DDNS registration in Samba DNS
dig @10.100.1.10 client1.lab.corp A
dig @10.100.1.10 client2.lab.corp A

# Kea lease database
docker exec dhcp1 cat /var/lib/kea/kea-leases4.csv

# DHCP server logs
docker exec dhcp1 journalctl -u kea-dhcp4 --no-pager -n 50
```

## What This Lab Teaches

- **DHCP doesn't just hand out IPs** — it configures DNS servers, NTP, domain name, and gateways
- **Dynamic DNS** is how DHCP-assigned hosts become resolvable by name automatically
- **TSIG keys** authenticate DDNS updates so random hosts cannot poison your DNS
- Lease management matters: short leases mean more DDNS churn; long leases mean stale records
- DHCP reservations bridge static and dynamic addressing

## Experiments

- Configure a scope with no available addresses and watch the DHCPNAK
- Send a DDNS update without the TSIG key and observe the rejection
- Configure a DHCP reservation for `client1`'s MAC address
- Capture the DORA exchange with tcpdump and trace each packet
