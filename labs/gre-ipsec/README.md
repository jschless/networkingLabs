# GRE over IPsec — Practice Lab (VyOS)

GRE gives you a routed overlay that carries multicast and routing
protocols — but in clear. IPsec gives you encryption — but plain IPsec
selectors don't carry multicast or routing protocols. GRE-over-IPsec is
the classic marriage: GRE for the overlay, IPsec **transport mode** to
encrypt it. You start with a working plaintext GRE tunnel, prove it's
exposed on the wire, then wrap it in ESP and prove the exposure is gone.

## Topology

```mermaid
flowchart LR
    ha(["host-a\n192.168.1.10"])
    gwa["gw-a\n203.0.113.1\ntun0: 172.16.0.1"]
    inet["internet\n203.0.113.2 / .5"]
    gwb["gw-b\n203.0.113.6\ntun0: 172.16.0.2"]
    hb(["host-b\n192.168.2.10"])

    ha -- "192.168.1.0/24" --- gwa
    gwa -- "203.0.113.0/30" --- inet
    inet -- "203.0.113.4/30" --- gwb
    gwb -- "192.168.2.0/24" --- hb

    gwa -. "GRE tun0 + IPsec" .- gwb
```

GRE `tun0` (172.16.0.0/30) and static inter-site routes are
**pre-configured and already working** — your job is to add IPsec.

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure**, **open hints before the solution**,
  and **verify** with packet captures on the WAN vs. the tunnel interface.

## Deploy and Access

```bash
docker build -t vyos:local -f Dockerfile.vyos .
./scripts/lab.sh deploy gre-ipsec
./scripts/lab.sh cli gre-ipsec gw-a
```

---

## Task 1 — Prove GRE works, and that it's naked

**Objective:** Confirm host-a ↔ host-b across the existing GRE tunnel,
then capture on the WAN and see the exposure.

**Predict first:** capturing on the transit link with filter `gre`, what
will you be able to read about the inner host-to-host traffic — source/
dest IPs? payload? both?

```bash
./scripts/lab.sh cmd gre-ipsec host-a ping -c3 192.168.2.10
./scripts/lab.sh capture gre-ipsec internet eth1 'gre'
```

<details markdown="1">
<summary>Check your work</summary>

The capture shows raw GRE packets with the inner IP header and ICMP
fully visible — anyone on the WAN path can read the private addressing
and payload. GRE encapsulates; it does not encrypt or authenticate. This
is the exact gap the rest of the lab closes, and the capture is your
"before" evidence.

</details>

---

## Task 2 — Encrypt the GRE with IPsec transport mode

**Objective:** Add a matching IKEv2 + ESP **transport-mode** policy on
both gateways, keyed to protect the GRE traffic between the WAN IPs
(`tunnel 1 protocol gre`, not LAN prefixes).

**Predict first:** the ipsec-basics lab used `mode tunnel` and LAN-prefix
selectors. Here it's `mode transport` and `protocol gre`. Why transport
mode — what header does it *avoid* adding, and why is that the right
choice when GRE is already providing the encapsulation?

<details markdown="1">
<summary>Hints</summary>

- IKE group as before (ikev2, aes256/sha256/dh14).
- ESP group: `mode transport` (the key difference).
- The peer's selector is `tunnel 1 protocol 'gre'` — you're protecting
  the GRE protocol between the two WAN IPs, not a LAN prefix pair.
- Mirror on gw-b with addresses/IDs swapped.

</details>

<details markdown="1">
<summary>Solution</summary>

On **gw-a** (gw-b mirrors with addresses/IDs swapped):
```vyos
configure
set vpn ipsec ike-group GRE-IPSEC key-exchange 'ikev2'
set vpn ipsec ike-group GRE-IPSEC proposal 10 encryption 'aes256'
set vpn ipsec ike-group GRE-IPSEC proposal 10 hash 'sha256'
set vpn ipsec ike-group GRE-IPSEC proposal 10 dh-group '14'
set vpn ipsec esp-group GRE-IPSEC mode 'transport'
set vpn ipsec esp-group GRE-IPSEC proposal 10 encryption 'aes256'
set vpn ipsec esp-group GRE-IPSEC proposal 10 hash 'sha256'
set vpn ipsec authentication psk LAB-PSK id '203.0.113.1'
set vpn ipsec authentication psk LAB-PSK id '203.0.113.6'
set vpn ipsec authentication psk LAB-PSK secret 'SuperSecret123'
set vpn ipsec site-to-site peer GW-B remote-address '203.0.113.6'
set vpn ipsec site-to-site peer GW-B authentication mode 'pre-shared-secret'
set vpn ipsec site-to-site peer GW-B authentication local-id '203.0.113.1'
set vpn ipsec site-to-site peer GW-B authentication remote-id '203.0.113.6'
set vpn ipsec site-to-site peer GW-B connection-type 'initiate'
set vpn ipsec site-to-site peer GW-B local-address '203.0.113.1'
set vpn ipsec site-to-site peer GW-B ike-group 'GRE-IPSEC'
set vpn ipsec site-to-site peer GW-B default-esp-group 'GRE-IPSEC'
set vpn ipsec site-to-site peer GW-B tunnel 1 protocol 'gre'
commit
save
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`show vpn ike sa` and `show vpn ipsec sa` show the SAs up (the child SA's
selector is the GRE protocol between the WAN IPs); host-a ↔ host-b still
pings. Prediction answer: transport mode protects the payload **without
adding a second outer IP header** — GRE already supplied the outer
WAN-routable header, so tunnel mode would just bloat every packet with a
redundant header (worse MTU, same security). Transport-mode-over-GRE is
the lean, standard pattern; tunnel-mode-over-GRE is a common
misconfiguration that "works" but wastes 20 bytes a packet.

</details>

---

## Task 3 — Prove the encryption on the wire

**Objective:** Re-capture the WAN and confirm raw GRE is gone, replaced by
ESP — then capture *inside* the tunnel and confirm the overlay is
unchanged.

```bash
./scripts/lab.sh capture gre-ipsec internet eth1 'udp port 500 or udp port 4500 or esp or gre'
./scripts/lab.sh capture gre-ipsec gw-a tun0 'icmp'
```

<details markdown="1">
<summary>Check your work</summary>

WAN capture: IKE on UDP/500 then **ESP** — and **no raw GRE** anymore;
the GRE packets are now encrypted *inside* ESP, invisible to the WAN.
`tun0` capture: the inner ICMP looks exactly as before, because at the
tunnel interface you're above the encryption layer. This before/after
pair is the whole point: same overlay, same routing, but the WAN now
carries opaque ESP instead of readable GRE. Layering encryption *under*
an existing overlay is a recurring design move (it reappears in SD-WAN and
DMVPN).

</details>

---

## Task 4 — Break it: drop one side's IPsec

**Objective:** Remove the IPsec config on gw-b only (leave GRE intact),
and determine what host-a ↔ host-b connectivity does.

**Predict first:** gw-a now demands ESP-protected GRE; gw-b sends plain
GRE. Does traffic fall back to plaintext GRE, or fail entirely? What does
that tell you about how IPsec policy enforces protection?

<details markdown="1">
<summary>What you should observe</summary>

Connectivity **fails** — it does not silently fall back to plaintext.
gw-a's IPsec policy says "GRE to 203.0.113.6 must be ESP-protected," so it
drops gw-b's unprotected GRE as a policy violation, and gw-b drops gw-a's
ESP because it has no SA to decrypt it. This is the correct, secure
behavior: a half-configured IPsec policy fails *closed*, not open — there
is no accidental downgrade to cleartext. (Contrast a pure-GRE
misconfiguration, which would happily keep passing traffic in the clear.)
Restore gw-b's IPsec and confirm the SAs and pings return.

</details>

---

## Verification

```bash
show vpn ike sa
show vpn ipsec sa
show interfaces tunnel tun0
./scripts/lab.sh cmd gre-ipsec host-a ping -c3 192.168.2.10
```

---

## Challenge questions

No answers provided — reason them through.

1. Why can GRE-over-IPsec run OSPF/EIGRP across the WAN while plain
   policy-based IPsec (the ipsec-basics lab) cannot? Trace what a
   multicast OSPF hello has to ride on in each design.
2. Each layer adds overhead: outer IP, then GRE, then ESP. Estimate the
   per-packet overhead and the effective inner MTU on a 1500-byte WAN,
   and explain why TCP MSS clamping on `tun0` is the usual fix rather
   than raising MTU.
3. Compare GRE-over-IPsec with a route-based VTI (IPsec tunnel interface)
   that also carries routing protocols. What does GRE add that a VTI
   doesn't, and why have many vendors moved to VTI anyway?
4. Task 4 failed closed. Design a deliberate "encrypt if possible, else
   plaintext" fallback and argue why that's almost always a security
   anti-pattern — what attack does it enable?

## Cleanup

```bash
./scripts/lab.sh destroy gre-ipsec
```

## Extensions

Optional follow-on ideas (not part of the validated workflow):

- Run OSPF across `tun0` instead of static routes.
- Add MSS clamping / change MTU and find what breaks first with large
  packets.
- Simulate a WAN failure and confirm GRE, IKE, and host reachability fail
  in the order you expect.
