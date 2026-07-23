# Wireless Authentication & Control Operations — Practice Lab

Operate the identity and policy side of enterprise WLAN access: EAP-TLS server
validation, FreeRADIUS authorization attributes, role-to-VLAN policy projection,
and a certificate-trust incident. This is the documented WP-02 fallback, not a
virtual WLAN: its live EAPOL runs over wired links and it makes **no** claim of
SSID discovery, association, four-way handshakes, roaming, RF propagation, or a
production WLC.

## Topology

```text
 corp-client --EAPOL--\                 /-- corp-service (VLAN 110)
 guest-client ---------- [authenticator] -- guest-service (VLAN 120)
 quarantine-client -EAPOL/       |       \-- quarantine-service (VLAN 130)
                                radius
```

| Segment | Prefix | Purpose |
|---|---|---|
| Management | `192.168.99.0/24` | RADIUS/authenticator inventory |
| VLAN 110 | `10.110.0.0/24` | Corporate role and approved service |
| VLAN 120 | `10.120.0.0/24` | Guest-policy fixture |
| VLAN 130 | `10.130.0.0/24` | Quarantine remediation role |

| Node | Role |
|---|---|
| `radius` | FreeRADIUS 3.2.1 EAP-TLS and authorization attributes |
| `authenticator` | Wired hostapd EAPOL authenticator, bridge policy projection, inventory API |
| `corp-client`, `quarantine-client` | EAP-TLS test clients with CA and server-name validation |
| `guest-client` | VLAN 120 policy fixture; it is not a wireless client |
| `*-service` | Role-scoped HTTP and ICMP fixtures |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an objective and
hints — your job is to produce the configuration or diagnosis.

- **Predict before you configure.** Commit to an answer before touching a CLI.
- **Open hints before solutions.** The solution toggle is an answer key.
- **Verify like an operator.** Check state and transaction evidence after each task.

## Deploy

```bash
docker build -t wireless-auth-control:local labs/wireless-auth-control-operations/
./scripts/lab.sh deploy wireless-auth-control-operations
./scripts/lab.sh bash wireless-auth-control-operations radius
```

The image is local and derives from
`debian:12.12-slim@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c`.
Run `./scripts/lab.sh destroy wireless-auth-control-operations` when finished.

## Task 1 — Survey the honest operating boundary

**Objective:** identify the live mechanisms and the explicitly unsupported radio
mechanisms before interpreting any evidence.

**Predict first:** can a successful EAP-TLS exchange prove a client roamed?

```bash
./scripts/lab.sh cmd wireless-auth-control-operations authenticator -- curl -fsS http://192.168.99.1:8080/
./labs/wireless-auth-control-operations/radio-cleanup.sh
```

<details markdown="1"><summary>Hints</summary>

- Read `PROBE.md`; the fallback intentionally has no hwsim PHY.
- Separate identity/control evidence from 802.11 or RF evidence.

</details>

<details markdown="1"><summary>Solution</summary>

EAP-TLS, RADIUS replies, hostapd wired EAPOL state, and bridge VLAN policy are
live. Association, roam, FT, RSSI/SNR, utilization, DFS, and WLC behavior are
not proven. EAP success cannot prove a roam.

</details>

<details markdown="1"><summary>Check your work</summary>

The API says `live_radio: false` and the cleanup check reports no hwsim PHY.
That boundary prevents an authorization result from being misreported as RF
behavior.

</details>

## Task 2 — Verify corporate EAP-TLS trust

**Objective:** prove that `corp-client` validates both the lab CA and the
expected RADIUS server name before accepting access.

**Predict first:** what fails first if the server certificate is replaced but
the SSID/network remains visible in a physical deployment?

<details markdown="1"><summary>Hints</summary>

- Inspect `/etc/wpa_supplicant/corp.conf` and `/var/log/wpa-corp.log`.
- Look for `ca_cert`, `domain_suffix_match`, and `CTRL-EVENT-EAP-SUCCESS`.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd wireless-auth-control-operations corp-client -- \
  'grep -E "ca_cert|domain_suffix_match" /etc/wpa_supplicant/corp.conf; tail -n 30 /var/log/wpa-corp.log'
```

</details>

<details markdown="1"><summary>Check your work</summary>

The config includes `domain_suffix_match="radius.lab"`; the log includes an
EAP success event. This proves server authentication is active, rather than a
client accepting any TLS certificate.

</details>

## Task 3 — Correlate authorization to VLAN 110

**Objective:** trace the corporate identity from RADIUS Access-Accept attributes
to the authenticator's live VLAN 110 port state and approved service.

**Predict first:** does an authentication success alone prove the user received
the intended authorization role?

<details markdown="1"><summary>Hints</summary>

- RADIUS logs contain `Tunnel-Private-Group-Id`.
- Compare `bridge vlan show dev eth1` with the corporate ping result.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd wireless-auth-control-operations radius -- \
  'grep -a -E "Access-Accept|Tunnel-Private-Group-Id" /var/log/freeradius/debug.log | tail -12'
./scripts/lab.sh cmd wireless-auth-control-operations authenticator -- 'bridge vlan show dev eth1'
./scripts/lab.sh cmd wireless-auth-control-operations corp-client -- 'ping -c3 10.110.0.1'
```

</details>

<details markdown="1"><summary>Check your work</summary>

The Access-Accept carries VLAN 110 and `eth1` is `110 PVID Egress Untagged`.
The corp service responds while the guest service does not. The policy projection
is visible at RADIUS, bridge, and data-path layers.

</details>

## Task 4 — Validate a quarantine authorization outcome

**Objective:** prove that a different accepted identity is authorized into VLAN
130 and cannot use corporate access.

**Predict first:** should an accepted EAP identity necessarily receive VLAN 110?

<details markdown="1"><summary>Hints</summary>

- Search for `quarantine-user` in the RADIUS log.
- Test both `10.130.0.1` and `10.110.0.1`.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd wireless-auth-control-operations quarantine-client -- 'ping -c3 10.130.0.1'
./scripts/lab.sh cmd wireless-auth-control-operations quarantine-client -- 'ping -c2 -W2 10.110.0.1 || true'
```

</details>

<details markdown="1"><summary>Check your work</summary>

The remediation service responds and the corporate service does not. This shows
authentication and authorization are separate decisions.

</details>

## Task 5 — Verify guest policy without inventing wireless behavior

**Objective:** confirm that VLAN 120 reaches only its guest fixture and document
why that is policy evidence, not an SSID/association result.

**Predict first:** can a VLAN 120 ping identify a channel or RSSI problem?

<details markdown="1"><summary>Hints</summary>

- `guest-client` has no wpa_supplicant configuration.
- Test the guest and corporate service addresses.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd wireless-auth-control-operations guest-client -- 'ping -c3 10.120.0.1'
./scripts/lab.sh cmd wireless-auth-control-operations guest-client -- 'ping -c2 -W2 10.110.0.1 || true'
```

</details>

<details markdown="1"><summary>Check your work</summary>

Guest access is limited to VLAN 120. The client is a wired policy fixture, so
neither result describes a live guest SSID or RF condition.

</details>

## Task 6 — Diagnose the client incident

**Objective:** given “the client cannot join but credentials work elsewhere,”
identify the failure layer using only client, RADIUS, and policy evidence.

**Predict first:** which evidence distinguishes certificate validation from a
bad password, a VLAN policy fault, and a coverage problem?

<details markdown="1"><summary>Hints</summary>

- Start with the client EAP log, then correlate a RADIUS request/response.
- Do not use `PROBE.md` to claim a radio observation that does not exist.

</details>

<details markdown="1"><summary>Solution</summary>

For a certificate failure, the client log rejects the server before a successful
EAP event; the RADIUS log shows no completed Access-Accept for that attempt.
For an authorization fault, EAP succeeds but the returned VLAN and bridge port
disagree with the expected role. Coverage/association is out of live scope and
must be assessed from the labeled evidence pack only.

</details>

<details markdown="1"><summary>Check your work</summary>

Record the evidence chain: client state → RADIUS transaction → bridge VLAN →
service reachability. A conclusion that skips one of those layers is incomplete.

</details>

## Task 7 — Break It: reject an untrusted RADIUS certificate

**Objective:** reproduce a corporate client failure while guest policy remains
available, diagnose server trust validation, and restore the intended chain.

```bash
./labs/wireless-auth-control-operations/break-it.sh
sleep 10
./labs/wireless-auth-control-operations/check.sh   # expected to fail
```

<details markdown="1"><summary>Hints</summary>

- Inspect `/var/log/wpa-corp.log` before changing anything.
- The permitted repair restores the CA-signed server certificate; do not remove
  `ca_cert` or `domain_suffix_match`.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./labs/wireless-auth-control-operations/repair-break-it.sh
sleep 10
./labs/wireless-auth-control-operations/check.sh
```

</details>

<details markdown="1"><summary>Check your work</summary>

During the break, corporate EAP success, VLAN 110 projection, and corporate
reachability fail while the guest fixture still reaches `10.120.0.1`. After the
repair all 17 checks pass without weakening validation.

</details>

## Task 8 — Analyze RF evidence without overclaiming

**Objective:** write an evidence chain for each record in
`labs/fixtures/wireless-core-operations/` that distinguishes high utilization,
weak coverage/driver uncertainty, and certificate validation failure.

**Predict first:** which two records could look similar to a helpdesk caller but
require different next tests?

<details markdown="1"><summary>Hints</summary>

- Read the fixture manifest before the CSV.
- Treat every measurement in this pack as synthetic evidence.

</details>

<details markdown="1"><summary>Solution</summary>

`client-b` supports a utilization hypothesis despite strong signal; `client-c`
supports weak coverage *or* driver investigation because EAP did not start;
`client-d` is an authentication-trust fault. None prove real RF values in this
lab.

</details>

<details markdown="1"><summary>Check your work</summary>

Each conclusion names the supporting artifact, at least one alternative, and a
limitation. Do not convert synthetic figures into a live survey claim.

</details>

## Verification

```bash
./labs/wireless-auth-control-operations/check.sh
```

All 17 assertions must pass in the golden state. They cover services, EAP-TLS
state, RADIUS role attributes, VLAN policy, negative segmentation, trust
configuration, inventory fidelity, and absence of hwsim use.

## Challenge questions

1. How would you carry RADIUS role attributes from this lab into a controller
   policy without calling the controller a RADIUS server?
2. What evidence would be required before claiming a real 802.11r roam?
3. How would you rotate the trusted CA with an overlap window and audit failed
   clients?
4. Which additional evidence separates sticky-client behavior from an RF hole?

## Troubleshooting

**EAP starts but never succeeds:** inspect the client certificate, CA, and
server-name validation first; then correlate the RADIUS debug log.

**EAP succeeds but service is wrong:** compare the Access-Accept VLAN attribute,
`bridge vlan show`, and the intended role service.

**A request asks for RSSI, channel, or roaming output:** this host cannot load
`mac80211_hwsim` non-interactively. Use the evidence pack and label the result
as evidence-only; do not fabricate a live RF metric.
