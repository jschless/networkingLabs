# Enterprise Grand Capstone — Design Notes

> The cross-track crown jewel (PLAN.md Phase 4.1/4.2). A real Cisco-style campus
> (Arista cEOS collapsed core + Linux/hostapd access) whose users authenticate
> and get their services from the **real Enterprise-IT-101 infrastructure**
> (Samba AD, FreeRADIUS, Kea DHCP+DDNS, mail, web proxy) running as Docker
> Compose containers, bridged into the ContainerLab topology.
>
> This file is the architecture record. The README is the student-facing lab.

## The two tooling stacks, bonded

| Stack | What it runs | How |
|-------|--------------|-----|
| **ContainerLab** | campus switches/routers + endpoints | `topology.clab.yml` |
| **Docker Compose** | EIT101 services on `lab-corp` (10.100.0.0/16) | `services/docker-compose.yml` |

The bond is the **4.0 finding**: the compose `lab-corp` network is created with a
**pinned Linux-bridge name** (`com.docker.network.bridge.name=br-eitcorp`), and the
clab topology contains a `bridge`-kind node of that exact name. cEOS/Linux campus
nodes wire a routed interface into it and get an IP in 10.100.0.0/16 — so the campus
and the services share L2/L3 at one controlled seam.

Deploy order (wrapper script `gcap.sh`): **services up first** (creates `br-eitcorp`),
then `containerlab deploy`. Teardown is the reverse.

## Why this topology size

One cEOS ≈ 1.5 GiB. A full 3-tier campus (10 cEOS) + the service stack would not
fit the 15 GiB lab host. So the campus is a **collapsed core** (2-tier) and the
access layer is **Linux** (which is also the only proven 802.1X authenticator path
— hostapd `driver=wired`). cEOS count = 4 (isp, edge, cc1, cc2).

```
        [isp]  AS65500  (cEOS)            == Internet / upstream
          | 203.0.113.0/30
        [edge] AS65100  (cEOS)            == NAT + DMZ firewall (eBGP + OSPF)
        /    \
   [cc1]======[cc2]  (cEOS)               == Collapsed core: L3 + VRRP + STP root
    |  \      /  |                           + DHCP relay (ip helper) + lab-corp SVI
    |   \    /   |
    |  (trunks: VLAN 10,20,30,99)
    |    \  /    |          \
[access-sw1]  [access-sw2]   `----> br-eitcorp ===== lab-corp (Docker Compose)
 (Linux,        (Linux,                                10.100.0.0/16:
  hostapd)       hostapd)                                dc1     10.100.1.10  (Samba AD + DNS)
   |    |          |                                     radius1 10.100.20.10 (FreeRADIUS->AD)
 corp  voip      guest                                   dhcp1   10.100.30.10 (Kea + DDNS)
 -pc   -phone    -pc                                      mail1   10.100.1.20  (Postfix/Dovecot)
                                                          proxy1  10.100.1.30  (Squid + Kerberos)
```

## Addressing

| Segment | Subnet | Gateway (VRRP VIP) |
|---------|--------|--------------------|
| VLAN 10 corporate | 10.10.10.0/24 | 10.10.10.1 |
| VLAN 20 voice | 10.20.20.0/24 | 10.20.20.1 |
| VLAN 30 guest | 10.30.30.0/24 | 10.30.30.1 |
| VLAN 99 mgmt | 192.168.99.0/24 | 192.168.99.1 |
| **Services seam (lab-corp)** | 10.100.0.0/16 | cc1=10.100.254.2 cc2=10.100.254.3, VIP **10.100.254.1** |
| WAN | 203.0.113.0/30 | isp=.1 edge=.2 |
| edge–core | 10.0.12.0/30, 10.0.22.0/30 | |
| core interlink | 10.0.99.0/30 | |
| Loopbacks | 10.0.0.x/32 | |

**Return path (4.0 finding):** the EIT101 service containers default-route to the
docker bridge gateway (the host), so they don't know how to reach 10.10.10.0/24 etc.
The wrapper adds **host routes** for the campus subnets via the core's lab-corp VIP
(`ip route add 10.10.10.0/24 via 10.100.254.1`, …). This is the lab-machine-only,
no-per-container-config approach.

## Integrations (the point of the lab)

1. **802.1X → FreeRADIUS → AD** *(proven end-to-end in the 4.1 prototype)*
   `corp-pc` (wpa_supplicant, PEAP/MSCHAPv2, AD user) → `access-sw1` (hostapd,
   `driver=wired`) → RADIUS to `radius1` (10.100.20.10, secret `testing123`) →
   `ntlm_auth` → `dc1` Samba AD → Access-Accept + dynamic VLAN (Tunnel-Private-Group-Id).
   The capstone ships `radius1`'s `clients.conf` with the access switches authorized
   (Lab 12 left that a student TODO).

2. **DHCP relay → Kea → DDNS into Samba DNS**
   cc1/cc2 VLAN SVIs carry `ip helper-address 10.100.30.10`; Kea (`dhcp1`) has a
   `subnet4` per campus VLAN keyed off the relay `giaddr`, and a DDNS hook that
   registers A/PTR into `dc1` Samba DNS. Campus clients DHCP from the real Kea and
   resolve in AD DNS.

3. **DMZ / firewall policy for mail + proxy**
   `edge` enforces policy (nftables/EOS ACL): VLAN 10 corporate may reach `proxy1`
   (web) and `mail1` (SMTP/IMAP); VLAN 30 guest is internet-only and **denied** the
   internal services; voice VLAN 20 isolated. `proxy1` does Kerberos `Negotiate`
   against AD (EIT101 Lab 11), so a corp user is SSO-authenticated to the proxy.

## Planted faults (4.2 — troubleshooting finale)

3–4 cross-layer faults whose *symptom layer ≠ cause layer*:

- **F1 — "Kerberos is broken"** that is really **DNS/routing**: corp-pc can't get a
  Kerberos ticket (proxy SSO + mail fail) because a campus SVI lost the `ip helper`/
  DNS path or a host return-route is missing — AD itself is fine.
- **F2 — "user can't get on the network"** = **RADIUS shared-secret mismatch** on one
  access switch (silent drop) — looks like an 802.1X/cert problem.
- **F3 — "no IP on VLAN 20"** = **DHCP relay helper** points at the wrong address /
  Kea has no `subnet4` for that giaddr — looks like a client problem.
- **F4 — "intermittent / half the users down"** = **VRRP or STP** role problem on the
  collapsed core — looks like a service outage.

Each fault: scenario → symptoms → 3-level hints → root cause → fix, following the
`debug-*` lab convention.

## Open validations (tracked as they're proven)

- [x] cEOS routed interface on `br-eitcorp` reaches a lab-corp service (L3) — proven
      2026-06-13: `Ethernet1 no switchport / ip 10.100.254.2/16` wired to the bridge
      node pinged a 10.100.1.50 service both ways; service routes back via a host route.
- [x] DHCP relay (cEOS `ip helper`) → Kea across the seam — proven: all 3 VLANs
      lease from the real Kea; Kea DDNS registers a PTR in bind9's campus zone.
- [x] Segmentation denies guest→services while permitting corp/voip — proven, BUT
      **moved off the SVI**: cEOS's virtual dataplane does NOT enforce SVI-applied
      ACLs (nor NAT). Enforced instead as an EGRESS ACL (`SEAM-OUT`) on the physical
      seam port Ethernet5. Internet is plain routing (ISP carries a static back to
      10.0.0.0/8) because cEOS source-NAT is a no-op that also breaks transit.
- [x] Full chain verified end-to-end from a clean `gcap.sh deploy` (2026-06-13):
      802.1X→AD, DHCP→Kea, DNS→AD, `kinit` TGT, DDNS PTR, guest segmentation, internet.
- [x] 802.1X PEAP → radius1 → Samba AD (proven in 4.1 prototype, 2026-06-13).
- [x] clab node ↔ lab-corp bridging, bidirectional + transit (4.0).
