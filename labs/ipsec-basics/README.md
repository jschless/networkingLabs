# IPsec Site-to-Site Tunnel — Practice Lab (VyOS)

Build an IKEv2 site-to-site IPsec tunnel between two VyOS gateways and
prove on the wire that LAN traffic crosses the WAN encrypted. Addressing
and base routing are pre-configured; you write the IPsec policy — IKE
group, ESP group, PSK, and the peer with its traffic selectors — then
break a proposal and diagnose the mismatch.

## Topology

```mermaid
flowchart LR
    ha(["host-a\n192.168.1.10"])
    gwa["gw-a\n192.168.1.1\n203.0.113.1"]
    inet["internet\n203.0.113.2 / .5"]
    gwb["gw-b\n203.0.113.6\n192.168.2.1"]
    hb(["host-b\n192.168.2.10"])

    ha -- "192.168.1.0/24" --- gwa
    gwa -- "203.0.113.0/30" --- inet
    inet -- "203.0.113.4/30" --- gwb
    gwb -- "192.168.2.0/24" --- hb

    gwa -. "IKEv2 / ESP tunnel" .- gwb
```

| Node | WAN | LAN |
|------|-----|-----|
| gw-a | 203.0.113.1 | 192.168.1.1/24 (host-a .10) |
| gw-b | 203.0.113.6 | 192.168.2.1/24 (host-b .10) |

`internet` forwards between the two WAN /30s. Cross-LAN traffic fails
until you build the tunnel.

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure**, **open hints before the solution**,
  and **verify** with `show vpn ike sa` / `show vpn ipsec sa` and a WAN
  packet capture.

## Deploy and Access

```bash
docker build -t vyos:local -f Dockerfile.vyos .   # if not already built
./scripts/lab.sh deploy ipsec-basics
./scripts/lab.sh cli ipsec-basics gw-a
./scripts/lab.sh bash ipsec-basics host-a
```

---

## Task 1 — Confirm the before-state

**Objective:** Show LAN-local works but cross-LAN doesn't, before any
IPsec.

```bash
./scripts/lab.sh cmd ipsec-basics host-a ping -c2 192.168.1.1    # ok
./scripts/lab.sh cmd ipsec-basics host-a ping -c2 192.168.2.10   # fails
```

<details>
<summary>Check your work</summary>

Local gateway pings succeed; host-a → host-b fails — the WAN won't route
RFC1918 and neither gateway tunnels the private traffic yet. IPsec will
both *route* (via traffic selectors) and *protect* that traffic. Keep
this baseline; it's what proves the tunnel did something.

</details>

---

## Task 2 — Build the tunnel on both gateways

**Objective:** Configure a matching IKEv2 site-to-site IPsec policy on
gw-a and gw-b — IKE group (aes256/sha256/DH14), ESP group (tunnel mode,
aes256/sha256), PSK, and a peer with selectors 192.168.1.0/24 ↔
192.168.2.0/24. Success: an IKE SA and a child SA come up.

**Predict first:** the two ends must *agree* on the IKE proposal, the ESP
proposal, the PSK, and the traffic selectors. Which of these, if
mismatched, fails at *Phase 1* (IKE) versus *Phase 2* (child SA)? Predict
where a wrong DH group fails versus a wrong selector.

<details>
<summary>Hints</summary>

- `vpn ipsec ike-group` (key-exchange ikev2, proposal with encryption/
  hash/dh-group) and `vpn ipsec esp-group` (mode tunnel, proposal).
- `vpn ipsec authentication psk` with both peer IDs and a shared secret.
- `vpn ipsec site-to-site peer <NAME>` with remote/local address,
  local-id/remote-id, ike-group, default-esp-group, and `tunnel 1
  local/remote prefix`.
- gw-b is the mirror — local and remote prefixes swap.

</details>

<details>
<summary>Solution</summary>

On **gw-a**:
```vyos
configure
set vpn ipsec ike-group SITE-TO-SITE key-exchange 'ikev2'
set vpn ipsec ike-group SITE-TO-SITE proposal 10 encryption 'aes256'
set vpn ipsec ike-group SITE-TO-SITE proposal 10 hash 'sha256'
set vpn ipsec ike-group SITE-TO-SITE proposal 10 dh-group '14'
set vpn ipsec esp-group SITE-TO-SITE mode 'tunnel'
set vpn ipsec esp-group SITE-TO-SITE proposal 10 encryption 'aes256'
set vpn ipsec esp-group SITE-TO-SITE proposal 10 hash 'sha256'
set vpn ipsec authentication psk LAB-PSK id '203.0.113.1'
set vpn ipsec authentication psk LAB-PSK id '203.0.113.6'
set vpn ipsec authentication psk LAB-PSK secret 'LabSecret123'
set vpn ipsec site-to-site peer GW-B remote-address '203.0.113.6'
set vpn ipsec site-to-site peer GW-B authentication mode 'pre-shared-secret'
set vpn ipsec site-to-site peer GW-B authentication local-id '203.0.113.1'
set vpn ipsec site-to-site peer GW-B authentication remote-id '203.0.113.6'
set vpn ipsec site-to-site peer GW-B connection-type 'initiate'
set vpn ipsec site-to-site peer GW-B local-address '203.0.113.1'
set vpn ipsec site-to-site peer GW-B ike-group 'SITE-TO-SITE'
set vpn ipsec site-to-site peer GW-B default-esp-group 'SITE-TO-SITE'
set vpn ipsec site-to-site peer GW-B tunnel 1 local prefix '192.168.1.0/24'
set vpn ipsec site-to-site peer GW-B tunnel 1 remote prefix '192.168.2.0/24'
commit
save
```

On **gw-b**: identical, but peer GW-A points at 203.0.113.1, the
local/remote IDs swap, and `tunnel 1 local prefix '192.168.2.0/24' /
remote prefix '192.168.1.0/24'`.

</details>

<details>
<summary>Check your work</summary>

`show vpn ike sa` shows an established IKE SA between 203.0.113.1 and
203.0.113.6; `show vpn ipsec sa` shows a child SA protecting the two /24s.
host-a ↔ host-b pings now work.

Prediction answer: IKE-group mismatches (DH group, encryption, hash, PSK)
fail in **Phase 1** — you'll have *no* IKE SA at all. ESP-group or traffic
selector mismatches fail in **Phase 2** — the IKE SA is up but *no child
SA* forms (or it forms with the wrong selectors and traffic silently
isn't matched). That split — "no IKE SA vs. IKE up but no child SA" — is
the single most useful triage signal in IPsec, and Task 4 makes you use
it.

</details>

---

## Task 3 — Prove it on the wire

**Objective:** Capture on the WAN and confirm the protected LAN traffic is
invisible (encrypted in ESP).

```bash
./scripts/lab.sh capture ipsec-basics internet eth1 'udp port 500 or udp port 4500 or esp'
# generate traffic: host-a ping host-b in another terminal
```

<details>
<summary>Check your work</summary>

You see UDP/500 (or 4500) during IKE negotiation, then **ESP** packets
once data flows — and crucially you cannot see the inner ICMP or the
192.168.x addresses, because they're encrypted inside ESP. Contrast with
the gre-basics lab, where the same WAN capture would show the inner
packets in clear (GRE encapsulates but doesn't encrypt). This capture is
the difference between "tunneled" and "protected."

</details>

---

## Task 4 — Break it: a proposal mismatch

**Objective:** Change gw-b's IKE proposal hash to `sha512` (leaving gw-a
at sha256), then diagnose from the SA tables which phase failed — without
peeking at the config.

**Predict first:** with only the IKE *hash* mismatched, will you see (a)
no IKE SA, (b) IKE SA up but no child SA, or (c) everything up but no
traffic?

<details>
<summary>What you should observe</summary>

`show vpn ike sa` shows **no established IKE SA** — the two ends can't
agree on a Phase 1 proposal, so negotiation never completes and there's
nothing to build a child SA on. This is case (a), confirming the
prediction: IKE-group parameters are Phase 1. If you'd instead mismatched
the *ESP* hash, you'd see the IKE SA up but no child SA (case b); a wrong
*selector* gives you up SAs but traffic that doesn't match and silently
isn't protected (case c). Repair gw-b back to sha256, commit, and confirm
both SAs return. Knowing which table to read first turns IPsec debugging
from guesswork into a two-step decision.

</details>

---

## Verification

```bash
show vpn ike sa                              # established IKE SA between WAN IPs
show vpn ipsec sa                            # child SA protecting the two /24s
show configuration commands | match vpn\ ipsec
./scripts/lab.sh cmd ipsec-basics host-a ping -c3 192.168.2.10
```

---

## Challenge questions

No answers provided — reason them through.

1. This is *policy-based* IPsec (traffic selectors decide what's
   encrypted). Contrast with *route-based* IPsec (VTI) where a routing
   table decides. Which makes "add a third site" easier, and which makes
   "run OSPF over the VPN" possible — and why?
2. PSK authentication uses one shared secret. Walk through the attack if
   that secret leaks versus if a per-peer certificate's key leaks, and
   why certificate auth scales to hundreds of spokes where PSK doesn't.
3. Insert NAT somewhere in the WAN path. Predict what changes in your
   Task 3 capture (which port, which behavior) and explain what NAT-T is
   actually solving about ESP.
4. The IKE SA rekeys on a timer and the child SA on a separate one. Why
   two lifetimes, what's the security reason the child SA's is usually
   shorter, and what user-visible symptom would a botched rekey produce?

## Cleanup

```bash
./scripts/lab.sh destroy ipsec-basics
```

## Extensions

Optional follow-on ideas (not part of the validated workflow):

- Swap the PSK for certificate-based authentication and compare the
  operational output.
- Rebuild as route-based IPsec with VTIs instead of policy selectors.
- Force NAT-T by inserting NAT in the path and watch ESP shift to UDP/4500.
