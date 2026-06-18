# Lab 06 — DHCP & Dynamic DNS

DHCP is how clients get an identity on the network without anyone touching them:
an address, a gateway, *and* the addresses of the DNS and NTP servers they
should use. **Dynamic DNS** closes the loop — when DHCP hands a client an
address, it registers that client's name in DNS automatically, so other hosts
can find it by name. In this lab you configure an ISC **Kea** DHCP server, watch
the DORA exchange on the wire, and wire up **TSIG-authenticated** DDNS so a
client that boots becomes resolvable seconds later.

## Topology

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       lab-corp  10.100.0.0/16                           │
│                                                                         │
│  ┌──────────┐   forward    ┌──────────┐  TSIG DDNS   ┌──────────┐       │
│  │   dc1    │◀─lab.corp────│   dns1   │◀─update──────│  dhcp1   │       │
│  │ AD DNS   │              │  BIND9   │  dhcp.lab.   │   Kea    │       │
│  │10.100.1.10│             │ resolver │   corp zone  │ DHCP+DDNS│       │
│  └──────────┘              │10.100.1.40│             │10.100.1.50│      │
│                            └──────────┘              └────┬─────┘       │
│                                  ▲                        │ DORA        │
│                                  │ DNS option 6           ▼ (broadcast) │
│                            ┌─────┴──────┐          ┌──────────────┐     │
│                            │  client1   │          │   client2    │     │
│                            │10.100.10.5x│          │ 10.100.10.5x │     │
│                            └────────────┘          └──────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

| Container | Image | IP | Role |
|-----------|-------|----|------|
| `dc1` | `samba-ad:local` | `10.100.1.10` | AD DC / DNS for `lab.corp` (foundation) |
| `dns1` | `bind9:local` | `10.100.1.40` | Resolver + authoritative for the dynamic `dhcp.lab.corp` zone (**given**) |
| `dhcp1` | `kea:local` (custom) | `10.100.1.50` | ISC Kea DHCP4 + DDNS — **you configure this** |
| `client1` | `workstation:local` | DHCP (`.10x`/`.150`) | DHCP client |
| `client2` | `workstation:local` | DHCP (`.10x`) | DHCP client |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective**
and **hints** — your job is to write the config. Then:

- **Predict before you run.** Commit to an answer first.
- **Reveal the solution only after you've tried.** Configs are behind `Solution`
  toggles. Reach for `man kea-dhcp4` and the
  [Kea ARM](https://kea.readthedocs.io/) structure first.
- **Observe, don't just verify.** The `Check your work` toggles explain the
  *mechanism*, not just the result.

You'll edit Kea's JSON configs on `dhcp1` and (re)start the daemons with the
`kea-start` helper. Kea's parser allows `//` comments, so you can annotate.

!!! note "A real-world wrinkle this lab teaches"
    DESIGN imagined DDNS updating the AD DNS directly. In reality, Samba/AD DNS
    only accepts **GSS-TSIG** (Kerberos-authenticated) dynamic updates — the
    mechanism domain-joined Windows machines use. A Linux DHCP server like Kea
    speaks ordinary **HMAC-TSIG** (a shared key), which AD DNS rejects. So the
    canonical Kea pattern (and this lab) points DDNS at a **BIND** zone —
    here `dhcp.lab.corp`, served by `dns1`. That's exactly how mixed
    Linux/Windows shops do it, and *why* is one of the lessons.

## Prerequisites

- **Labs 01–05 foundation.** Build the images if you haven't:

```bash
cd enterprise-it-101
docker build -t samba-ad:local   images/samba-ad/
docker build -t workstation:local images/workstation/
docker build -t bind9:local       images/bind9/
docker build -t kea:local         images/kea/
```

## Deploy

```bash
cd enterprise-it-101
docker compose -f base/docker-compose.yml \
               -f labs/06-dhcp-dynamic-dns/docker-compose.override.yml up -d
```

Wait ~20–30 s for `dc1` to provision. Confirm `dns1` is healthy:
`docker exec dns1 named-checkconf`.

## Destroy

```bash
docker compose -f base/docker-compose.yml \
               -f labs/06-dhcp-dynamic-dns/docker-compose.override.yml down -v
```

---

## What is pre-built

- `dc1` — AD DC/DNS (foundation).
- `dns1` — the Lab 05 resolver **plus** an authoritative, dynamically-updatable
  zone `dhcp.lab.corp` that accepts TSIG updates with the key `kea-ddns`. You
  don't edit `dns1`.
- The shared **TSIG key** is mounted into `dhcp1` at `/etc/kea/ddns.key` — the
  way a DNS team hands a key to whoever runs DHCP.
- `dhcp1` — Kea installed but **`/etc/kea` is empty**. Writing the config is the
  lab. Start/stop with `kea-start` / `kea-stop`.
- `client1` / `client2` — DHCP clients (granted `NET_ADMIN` so a lease can
  actually be applied to their interface).

## What you configure

`kea-dhcp4.conf` (the DHCP server) and `kea-dhcp-ddns.conf` (the DDNS bridge),
both in `/etc/kea/` on `dhcp1`.

---

## Task 1 — Stand up the DHCP server

**Objective:** Write `/etc/kea/kea-dhcp4.conf` with a pool of
`10.100.10.100–10.100.10.200`, a 600-second lease, and options that hand clients
the resolver (`dns1`), the domain (`lab.corp`), and the NTP server. Start Kea and
get `client1` a lease.

??? question "Predict first"
    `client1` already shows an IP on `eth0` (Docker's IPAM assigned
    `10.100.10.51` at container creation — that is **not** DHCP). After you run
    `dhclient`, will that `.51` address be **replaced**, or will the DHCP lease
    appear **alongside** it? And which IP range will the lease come from?

??? note "Hints"
    - A Kea config is one JSON object: `{ "Dhcp4": { … } }`.
    - You need `interfaces-config` (`"interfaces": ["eth0"]`), a
      `lease-database` (`memfile` persisting to
      `/var/lib/kea/kea-leases4.csv`), `valid-lifetime`, and a `subnet4` array.
    - The subnet is `10.100.0.0/16` with a `pools` entry for the `.100–.200`
      range. Per-subnet `option-data` carries `domain-name-servers`,
      `domain-name`, `ntp-servers`.
    - Validate without starting: `kea-dhcp4 -t /etc/kea/kea-dhcp4.conf`.
    - Start the daemons: `docker exec dhcp1 kea-start`. On the client:
      `dhclient -r eth0` (release) then `dhclient -v eth0` (request).

??? note "Solution"
    On `dhcp1` (`docker exec -it dhcp1 vim /etc/kea/kea-dhcp4.conf`):
    ```json
    {
      "Dhcp4": {
        "interfaces-config": { "interfaces": [ "eth0" ] },
        "lease-database": {
          "type": "memfile", "persist": true,
          "name": "/var/lib/kea/kea-leases4.csv"
        },
        "valid-lifetime": 600,
        "subnet4": [
          {
            "id": 1,
            "subnet": "10.100.0.0/16",
            "pools": [ { "pool": "10.100.10.100 - 10.100.10.200" } ],
            "option-data": [
              { "name": "domain-name-servers", "data": "10.100.1.40" },
              { "name": "domain-name",         "data": "lab.corp" },
              { "name": "ntp-servers",         "data": "10.100.1.20" }
            ]
          }
        ],
        "loggers": [ { "name": "kea-dhcp4", "severity": "INFO",
          "output_options": [ { "output": "stdout" } ] } ]
      }
    }
    ```
    ```bash
    docker exec dhcp1 kea-dhcp4 -t /etc/kea/kea-dhcp4.conf   # validate
    docker exec dhcp1 kea-start
    docker exec client1 bash -c 'dhclient -r eth0; dhclient -v eth0'
    docker exec client1 ip -4 addr show eth0
    ```

??? success "Check your work"
    `dhclient` logs `DHCPDISCOVER → DHCPOFFER of 10.100.10.100 → DHCPREQUEST →
    DHCPACK`, and `ip addr` shows **both** addresses:
    ```
    inet 10.100.10.51/16  … eth0
    inet 10.100.10.100/16 … secondary dynamic eth0
    ```
    The lease appears **alongside** Docker's address as a `secondary` — Docker's
    IPAM gave `.51` at creation; Kea's DHCP gave `.100` just now. In a real
    network there is no Docker IPAM, only DHCP, so the lease *is* the address.
    Seeing the two side by side is a useful reminder that **container networking
    and DHCP are different layers** — Docker doesn't use DHCP at all.

    (If `dhclient` says `RTNETLINK: Operation not permitted`, the client is
    missing the `NET_ADMIN` capability — it's set in the compose file; redeploy.)

---

## Task 2 — Watch DORA on the wire

**Objective (make the invisible visible):** Capture the four-packet DHCP
exchange and confirm it's **broadcast-based** — the reason a client with no IP
can still talk to a server it has never heard of.

??? question "Predict first"
    A client booting with no address sends its first DHCP packet to what
    destination IP, from what source IP? Why can't it just unicast to the DHCP
    server the way it would to any other host?

??? note "Hints"
    - Capture on `dhcp1`: `tcpdump -nv -i any "udp port 67 or udp port 68"`.
    - In another shell, force a fresh exchange:
      `docker exec client1 bash -c 'dhclient -r eth0; dhclient eth0'`.
    - Look at the `DHCP-Message` option in each packet: Discover, Offer,
      Request, ACK = **DORA**.

??? note "Solution"
    ```bash
    # shell 1
    docker exec dhcp1 tcpdump -nv -i any "udp port 67 or udp port 68"
    # shell 2
    docker exec client1 bash -c 'dhclient -r eth0; sleep 1; dhclient eth0'
    ```

??? success "Check your work"
    The Discover and Request go **`0.0.0.0.68 > 255.255.255.255.67`** — source
    `0.0.0.0` (the client has no address yet), destination the broadcast address
    (it doesn't know the server's address yet). That's the answer to the
    prediction: **you can't unicast when you have neither your own address nor
    the server's** — so DHCP bootstraps over broadcast. The Offer and ACK come
    back from `10.100.1.50.67`. Four packets — **D**iscover, **O**ffer,
    **R**equest, **A**ck — and the client is on the network. (This broadcast is
    also why DHCP doesn't cross routers without a *relay*/`giaddr` — a detail
    that matters the moment you have more than one subnet.)

---

## Task 3 — Inspect what DHCP actually delivered

**Objective:** DHCP hands out far more than an address. Read the **lease
database** on the server and the **lease file** on the client to see the address,
the options, and (soon) the DDNS state.

??? question "Predict first"
    Besides an IP address, name two other pieces of configuration `client1`
    received that it did **not** have to be told manually — and which enterprise
    service each one points it at.

??? note "Hints"
    - Server side: `cat /var/lib/kea/kea-leases4.csv` on `dhcp1`.
    - Client side: `cat /var/lib/dhcp/dhclient.leases` on `client1` — look at the
      `option …` lines.

??? note "Solution"
    ```bash
    docker exec dhcp1 cat /var/lib/kea/kea-leases4.csv
    docker exec client1 grep -E "fixed-address|option (domain|domain-name-servers)" \
        /var/lib/dhcp/dhclient.leases
    ```

??? success "Check your work"
    The client's lease records `option domain-name-servers 10.100.1.40` and
    `option domain-name "lab.corp"` — it learned its **resolver** (the Lab 05
    BIND server) and **search domain** from DHCP, plus the NTP server. That's the
    point of the prediction: DHCP is not "an IP vending machine," it's how a host
    learns *the entire local service environment* — DNS, NTP, domain, gateway —
    in one exchange. The Kea lease CSV shows the assigned IP, the client MAC, the
    expiry, and a hostname column (blank for now — Task 4 fills it).

---

## Task 4 — Register clients in DNS automatically (TSIG DDNS)

**Objective:** Configure Kea to send a **dynamic DNS update** to `dns1` every
time it grants a lease, authenticated with the **TSIG** key you were given, so
that `client1.dhcp.lab.corp` resolves to `client1`'s leased address.

??? question "Predict first"
    The TSIG key at `/etc/kea/ddns.key` is *also* configured on `dns1`
    (`allow-update { key "kea-ddns"; }`). What does requiring this shared key
    prevent — i.e., what could any host on the network do to your DNS if updates
    were *unauthenticated*?

??? note "Hints"
    - Two pieces: (a) a `kea-dhcp-ddns.conf` that holds the TSIG key and the
      target zone/server, and (b) a `dhcp-ddns` block + `ddns-*` settings in
      `kea-dhcp4.conf` telling DHCP4 to *send* updates.
    - Read the key's secret from the file you were given:
      `grep secret /etc/kea/ddns.key`.
    - In `kea-dhcp-ddns.conf`: a `tsig-keys` array (name `kea-ddns`, algorithm
      `HMAC-SHA256`, the secret), and `forward-ddns.ddns-domains` mapping
      `dhcp.lab.corp.` → `dns1` (`10.100.1.40`) using that key.
    - In `kea-dhcp4.conf`: add `"dhcp-ddns": { "enable-updates": true,
      "server-ip": "127.0.0.1", "server-port": 53001 }`, plus
      `"ddns-send-updates": true`, `"ddns-qualifying-suffix": "dhcp.lab.corp"`,
      and `"ddns-replace-client-name": "never"` (so Kea uses the client's own
      hostname). Set `"ddns-override-no-update": true` and
      `"ddns-override-client-update": true` so Kea owns the record.
    - The client must *send* a hostname for Kea to name it:
      `echo 'send host-name = gethostname();' > /etc/dhcp/dhclient.conf` on the
      client.

??? note "Solution"
    `/etc/kea/kea-dhcp-ddns.conf` on `dhcp1` (paste your real secret):
    ```json
    {
      "DhcpDdns": {
        "ip-address": "127.0.0.1", "port": 53001,
        "tsig-keys": [
          { "name": "kea-ddns", "algorithm": "HMAC-SHA256",
            "secret": "PASTE-SECRET-FROM-/etc/kea/ddns.key" }
        ],
        "forward-ddns": {
          "ddns-domains": [
            { "name": "dhcp.lab.corp.", "key-name": "kea-ddns",
              "dns-servers": [ { "ip-address": "10.100.1.40" } ] }
          ]
        },
        "loggers": [ { "name": "kea-dhcp-ddns", "severity": "INFO",
          "output_options": [ { "output": "stdout" } ] } ]
      }
    }
    ```
    Add to the `Dhcp4` object in `kea-dhcp4.conf` (alongside `subnet4`):
    ```json
        "dhcp-ddns": { "enable-updates": true,
                       "server-ip": "127.0.0.1", "server-port": 53001 },
        "ddns-send-updates": true,
        "ddns-qualifying-suffix": "dhcp.lab.corp",
        "ddns-replace-client-name": "never",
        "ddns-override-no-update": true,
        "ddns-override-client-update": true,
    ```
    Restart and re-lease:
    ```bash
    docker exec dhcp1 kea-start
    docker exec client1 bash -c 'echo "send host-name = gethostname();" > /etc/dhcp/dhclient.conf'
    docker exec client1 bash -c 'dhclient -r eth0; dhclient eth0'
    sleep 2
    docker exec client1 dig @10.100.1.40 client1.dhcp.lab.corp A +short   # → leased IP
    ```

??? success "Check your work"
    `dig client1.dhcp.lab.corp` returns `client1`'s leased address (e.g.
    `10.100.10.100`). The chain: client sends hostname → Kea grants a lease and
    fires a **NameChangeRequest** to `kea-dhcp-ddns` → that daemon sends a
    **TSIG-signed RFC 2136 update** to `dns1` → BIND verifies the signature
    against `allow-update { key "kea-ddns" }` and writes the record. The Kea lease
    CSV now shows `client1.dhcp.lab.corp` in the hostname column.

    The prediction's answer: without TSIG, **any host on the network could
    inject or overwrite DNS records** — claim to be the mail server, hijack a
    hostname, redirect traffic. The shared key means `dns1` only accepts updates
    from something that proves it holds the key. This is also *why* AD DNS
    insists on GSS-TSIG (Kerberos) for the same job — unauthenticated dynamic
    DNS is a disaster.

---

## Task 5 — Pin a client with a DHCP reservation

**Objective:** Give `client1` a **stable** address (`10.100.10.150`) by
reserving it to `client1`'s MAC, so it always gets the same IP without being
statically configured.

??? question "Predict first"
    `.150` sits *inside* the dynamic pool (`.100–.200`). When you reserve it to
    `client1`'s MAC, what does Kea do with that address for *every other*
    client — and why doesn't that cause a duplicate-address conflict? And the
    bigger question: why reserve `.150` at the DHCP server at all, rather than
    just statically configuring `10.100.10.150` on `client1` itself? What do you
    keep (and what do you give up) by doing it at the server instead of on the
    host?

??? note "Hints"
    - Look up `client1`'s real MAC first — reservations match on it:
      `docker exec client1 cat /sys/class/net/eth0/address`.
    - Add a `reservations` array inside the `subnet4` entry:
      `{ "hw-address": "<MAC>", "ip-address": "10.100.10.150", "hostname": "client1" }`.
    - Restart Kea and re-lease `client1`.

??? note "Solution"
    ```bash
    MAC=$(docker exec client1 cat /sys/class/net/eth0/address)
    echo "client1 MAC = $MAC"     # paste into the reservation below
    ```
    Inside the `subnet4` entry in `kea-dhcp4.conf`:
    ```json
        "reservations": [
          { "hw-address": "<MAC>", "ip-address": "10.100.10.150",
            "hostname": "client1" }
        ]
    ```
    ```bash
    docker exec dhcp1 kea-start
    docker exec client1 bash -c 'dhclient -r eth0; dhclient -v eth0' 2>&1 | grep DHCPACK
    # → DHCPACK of 10.100.10.150
    ```

??? success "Check your work"
    `client1` now gets `10.100.10.150` — its reserved address — every time, and
    `client1.dhcp.lab.corp` follows it in DNS. The trade-off you predicted:
    reserving at the DHCP server keeps addressing **centrally managed** (you can
    see, audit, and change every host's address from one place, and the host
    still learns DNS/NTP/domain from DHCP), whereas a static IP on the host is
    invisible to the server and a common source of duplicate-address conflicts.
    Reservations are how you give servers and printers stable addresses *without*
    abandoning central management.

---

## Task 6 — Watch a lease (and its DNS record) get cleaned up

**Objective:** Release a lease and confirm that DDNS **removes** the
corresponding DNS record — the other half of dynamic DNS that keeps stale
records from piling up.

??? question "Predict first"
    When `client1` releases its lease (`dhclient -r`), Kea should remove
    `client1.dhcp.lab.corp` from `dns1`. *Why does this matter?* What goes wrong
    over weeks if DHCP adds records on lease but never removes them on release or
    expiry?

??? note "Hints"
    - `docker exec client1 dhclient -r eth0` sends a DHCPRELEASE.
    - Then query the record again: `dig @10.100.1.40 client1.dhcp.lab.corp A`.

??? note "Solution"
    ```bash
    docker exec client1 dig @10.100.1.40 client1.dhcp.lab.corp A +short   # present
    docker exec client1 dhclient -r eth0
    sleep 2
    docker exec client1 dig @10.100.1.40 client1.dhcp.lab.corp A +short   # gone
    ```

??? success "Check your work"
    After the release the record is **gone** (empty answer). Kea fired a
    `CHG_REMOVE` NameChangeRequest and `dns1` deleted the record. The prediction:
    without cleanup, DNS slowly fills with **stale records** pointing at
    addresses that have since been reassigned to *other* clients — so a lookup
    for `client1` could return an IP now used by `client2`. Add/remove symmetry
    (and the lease lifetime, which bounds how stale a record can get on a hard
    crash) is what keeps dynamic DNS honest. Shorter leases = fresher records but
    more update churn; that's the lease-time trade-off.

---

## Task 7 — Break it: corrupt the TSIG key and diagnose silent DDNS failure

**Objective (required):** Change the TSIG secret in Kea so it no longer matches
`dns1`, watch new clients **get leases but silently fail to register in DNS**,
diagnose it from the logs, and repair. This is the most realistic DDNS failure
there is — DHCP "works," but names don't resolve.

??? question "Predict first"
    You corrupt only the **DDNS** key (not DHCP). When `client2` requests a
    lease, will the lease itself **succeed or fail**? Will `client2.dhcp.lab.corp`
    resolve? Where will the *only* sign of trouble appear?

**Break it** — on `dhcp1`, change the secret in `kea-dhcp-ddns.conf` to a
different valid-looking base64 string, then restart and clear the ddns log:
```bash
docker exec dhcp1 sed -i 's/"secret": "[^"]*"/"secret": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="/' \
    /etc/kea/kea-dhcp-ddns.conf
docker exec dhcp1 bash -c ': > /var/log/kea-ddns.log'
docker exec dhcp1 kea-start
```

**Now diagnose** — lease a fresh client and look:
```bash
docker exec client2 bash -c 'echo "send host-name = gethostname();" > /etc/dhcp/dhclient.conf'
docker exec client2 bash -c 'dhclient -r eth0; dhclient -v eth0' 2>&1 | grep DHCPACK   # lease OK?
docker exec client2 dig @10.100.1.40 client2.dhcp.lab.corp A +short                    # resolves?
docker exec dhcp1 tail -5 /var/log/kea-ddns.log                                        # the only clue
```

??? note "Diagnosis hints (try before revealing)"
    - Did the `DHCPACK` arrive? Did `dig` return anything?
    - The DHCP server and the DDNS server are **two different daemons**. Which
      one would log a problem — and which logs would a junior admin forget to
      check?
    - What does the `kea-dhcp-ddns` log say about the *response from the DNS
      server*? Why would a TSIG mismatch look like a "corrupt response" to Kea?

??? success "What you should observe"
    - The **lease succeeds** — `DHCPACK of 10.100.10.x` — because DHCP itself is
      untouched. This is the trap: the user "has an IP," so DHCP looks healthy.
    - `client2.dhcp.lab.corp` **does not resolve** (empty).
    - The **only** evidence is in `kea-dhcp-ddns`'s log:
      `DHCP_DDNS_FORWARD_ADD_RESP_CORRUPT … received a corrupt response from the
      DNS server, 10.100.1.40` followed by `DHCP_DDNS_ADD_FAILED … Forward
      change: failed`. Kea calls it "corrupt" because `dns1` rejected the update
      and signed its refusal with the *real* key — which Kea, holding the wrong
      key, can't verify, so the reply looks like garbage to it.

    The lesson: **DHCP and DDNS fail independently.** "I got an address but the
    name doesn't resolve" points you at the DDNS path (keys, the ddns daemon,
    the DNS server's `allow-update`), *not* at DHCP. Checking only the DHCP
    server would tell you everything is fine.

**Repair it** — restore the correct secret from the key file and restart:
```bash
SECRET=$(docker exec dhcp1 grep secret /etc/kea/ddns.key | sed 's/.*secret "//;s/".*//')
docker exec dhcp1 sed -i "s|\"secret\": \"[^\"]*\"|\"secret\": \"$SECRET\"|" /etc/kea/kea-dhcp-ddns.conf
docker exec dhcp1 kea-start
docker exec client2 bash -c 'dhclient -r eth0; dhclient eth0'
sleep 2
docker exec client2 dig @10.100.1.40 client2.dhcp.lab.corp A +short   # resolves again
```

---

## Verification Checklist

```bash
# DHCP: client gets a pool/reserved address via DORA
docker exec client1 bash -c 'dhclient -r eth0; dhclient -v eth0' 2>&1 | grep DHCPACK

# Options delivered (resolver + domain)
docker exec client1 grep "domain-name-servers" /var/lib/dhcp/dhclient.leases

# DDNS: leased clients are resolvable by name
docker exec client1 dig @10.100.1.40 client1.dhcp.lab.corp A +short
docker exec client2 dig @10.100.1.40 client2.dhcp.lab.corp A +short

# Lease database shows leases + hostnames
docker exec dhcp1 cat /var/lib/kea/kea-leases4.csv

# DDNS cleanup on release
docker exec client1 dhclient -r eth0 && sleep 2 && \
  docker exec client1 dig @10.100.1.40 client1.dhcp.lab.corp A +short   # empty
```

---

## Challenge Questions

1. **DORA across a router.** `client1`'s Discover is a broadcast, and broadcasts
   don't cross routers. In a real multi-subnet network the DHCP server is usually
   *not* on the client's subnet. What network device/feature bridges that gap,
   and what field in the DHCP packet tells the server which subnet's pool to draw
   from?

2. **The "I have an IP but no name" ticket.** A user reports they can browse the
   web but a colleague can't reach their machine by name. Walk through where you'd
   look, in order, given what you saw in Task 7 — and explain why the DHCP server
   logs are the *wrong* place to start.

3. **GSS-TSIG vs. HMAC-TSIG.** This lab pointed DDNS at a BIND zone because AD
   DNS only accepts GSS-TSIG. In a Windows-centric shop, *how* do clients end up
   registered in AD DNS without a Kea server — what does the work, and what
   authenticates it? (Think about what a domain-joined machine already has.)

4. **Lease time tuning.** You run a conference Wi-Fi with 2000 devices churning
   through a /22. Argue for a specific lease time. Now argue for the *opposite*
   for a stable office of 50 desks. What breaks at each extreme?

5. **Design extension.** Lab 11 adds a web proxy that clients should auto-detect.
   DHCP option 252 (WPAD) can hand clients a proxy-config URL. Given what you
   built, where would you add it, and what's the security risk of distributing a
   proxy URL over *unauthenticated* DHCP?

---

## Key Concepts

**DHCP is service bootstrapping, not just addressing.** One DORA exchange gives a
client its address **and** its DNS, NTP, domain, and gateway — the whole local
environment. DORA = Discover / Offer / Request / Ack, bootstrapped over broadcast
because the client starts with no address and no server address.

| Piece | Where | Job |
|-------|-------|-----|
| `subnet4` + `pools` | `kea-dhcp4.conf` | The address range to hand out |
| `option-data` | `kea-dhcp4.conf` | DNS/NTP/domain a client learns automatically |
| `reservations` | `kea-dhcp4.conf` | Stable IP for a known MAC, still centrally managed |
| `dhcp-ddns` + `ddns-*` | `kea-dhcp4.conf` | Tells DHCP4 to fire DNS updates |
| `kea-dhcp-ddns.conf` | the DDNS daemon | Holds the TSIG key + target zone/server |
| `allow-update { key }` | `dns1` (BIND) | Only accepts updates signed by the shared key |

**DDNS = add **and** remove.** Records are created on lease and deleted on
release/expiry; the symmetry (plus lease time) is what keeps DNS from filling
with stale, dangerous records.

**TSIG authenticates updates.** Without it, anyone could rewrite your DNS. AD DNS
uses Kerberos (GSS-TSIG) for the same reason; Kea uses shared-key HMAC-TSIG,
which is why DDNS here targets a BIND zone, not AD DNS directly.

**DHCP and DDNS fail independently.** "Got an address but no DNS name" is a DDNS
problem (key/daemon/`allow-update`), never a DHCP problem — they're separate
daemons with separate logs.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `dhclient`: `RTNETLINK: Operation not permitted` | Client lacks `NET_ADMIN` | It's in the compose file — redeploy; or `--cap-add NET_ADMIN` |
| No `DHCPOFFER` at all | Kea not running / wrong interface | `docker exec dhcp1 kea-start`; check `interfaces-config` |
| Lease works, name doesn't resolve | DDNS path broken (Task 7) | Check `kea-dhcp-ddns` log + TSIG secret + `allow-update` |
| `kea-dhcp4 -t` errors | JSON syntax / bad option name | Read the parse error; Kea points at the line |
| DDNS name is `myhost-<ip>` not the hostname | `ddns-replace-client-name` not `never`, or client sent no hostname | Set `never`; `send host-name` in `dhclient.conf` |
| `docker cp` into `dhcp1` says "resource busy" | You bind-mounted a config read-only | Edit in-container (`vim`) instead |
| Record never cleaned up after release | `dhclient -r` not run / DDNS down | Release explicitly; confirm the ddns daemon is up |

---

## What's Next

- **Lab 07 (File Shares)** — clients that get addresses and names here will mount
  Kerberos-authenticated SMB shares; stable names make ACLs and auditing sane.
- **Lab 09 (Email Gateway)** — relies on forward **and** reverse DNS; the
  add/remove discipline you built keeps records trustworthy.
- **Lab 11 (Web Proxy)** — revisits DHCP options (WPAD/option 252) to
  auto-configure clients, building directly on this config.
