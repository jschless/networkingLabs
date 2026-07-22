# WP-02 — Wireless Core Operations

## Outcome

Replace the current VLAN-only wireless architecture approximation with
`labs/wireless-core-operations/`, a practice lab that uses Linux virtual 802.11
radios where the host can support them, plus a first-class RF evidence-analysis
module. Students should form real associations, authenticate through RADIUS,
observe roaming and key-management behavior, separate corp/guest policy, and
diagnose a client-connectivity incident without any claim that containers emulate
physical RF propagation.

Target: level 4 for 802.11/auth/control operations and level 1 for RF/survey work.

## Non-negotiable fidelity split

Live if the prototype succeeds:

- `mac80211_hwsim` virtual radios moved into container namespaces;
- hostapd APs and wpa_supplicant clients;
- WPA2/WPA3-Enterprise-compatible EAP authentication through FreeRADIUS;
- 802.11 association/authentication state, four-way handshake, VLAN assignment;
- 802.11r fast-transition mechanics between two APs where supported;
- controller-like configuration inventory and AP health, clearly labeled as a
  management service rather than a production WLC.

Evidence-only, visibly labeled:

- RSSI/SNR and attenuation;
- channel utilization, CCI/ACI, DFS/radar, retries caused by RF;
- coverage/capacity survey interpretation;
- sticky clients and client-driver interoperability;
- real 6 GHz spectrum behavior.

The existing `enterprise-wireless-architecture` remains a prerequisite/reference;
do not rename it or overstate it.

## Load-bearing feature probe

Do not build the lab until a disposable probe proves:

1. The lab host can load a pinned-compatible `mac80211_hwsim` module without
   destabilizing host networking.
2. At least four virtual radios can be assigned deterministically to two AP and
   two station namespaces/containers and are removed cleanly on destroy.
3. hostapd and wpa_supplicant can associate across namespaces.
4. EAP-TLS or PEAP succeeds through FreeRADIUS.
5. A station can transition from AP1 to AP2 with observable event logs; test
   802.11r support explicitly rather than assuming it.
6. Repeated deploy/destroy cycles leave no orphan PHYs, interfaces, bridge ports,
   processes, or module parameters.

If this probe fails, do **not** ship another Ethernet bridge as a “wireless” lab.
Ship a smaller `wireless-auth-control-operations` live lab and retain association,
roaming, and RF as evidence-analysis exercises. Record the failed capability and
host/kernel version in `PROBE.md`.

## Lab type and platform

- Type: practice, with a reference RF evidence section.
- APs/clients: custom pinned Debian/Ubuntu Linux image with hostapd,
  wpa_supplicant, `iw`, tcpdump, openssl, and log tooling.
- `dist1`: cEOS for VLAN gateway, DHCP relay, ACL/QoS policy.
- `radius`: reuse or derive from the proven NAC/FreeRADIUS image; do not fork
  credentials/config unnecessarily.
- `wlan-manager`: lightweight API/inventory service that reports AP registration,
  configured SSIDs, channel assignment, and client count; label it a pedagogical
  control service, not a WLC emulator.

## Topology and addressing

```text
                     wlan-manager
                          |
 radius --- dist1 --- ap1 )))) corp-sta
                  \-- ap2 )))) guest-sta
                         \)))) roam-sta
```

| VLAN | Prefix | Purpose |
|---:|---|---|
| 99 | `192.168.99.0/24` | AP/controller/RADIUS management |
| 110 | `10.110.0.0/24` | Corporate wireless clients |
| 120 | `10.120.0.0/24` | Guest wireless clients |
| 130 | `10.130.0.0/24` | Quarantine/dynamic authorization |

Prebuild addressing, PKI, user identities, AP uplink trunks, DHCP/DNS, test
applications, and virtual-radio assignment. Withhold SSIDs, EAP policy, dynamic
VLAN rules, roaming domain, and wired segmentation policy.

## Student task sequence

1. **Guided radio and dependency survey:** inspect PHY/interface placement, AP
   management reachability, RADIUS reachability, wired trunks, and empty association tables.
2. **Hinted corporate WLAN:** configure an enterprise SSID, EAP server validation,
   RADIUS client, certificate trust, and dynamic VLAN authorization. Prove the
   station is associated and placed in VLAN 110.
3. **Hinted guest WLAN:** configure an isolated guest SSID using the chosen lab-safe
   security mode, local breakout, DHCP, and deny-to-corporate policy.
4. **Hinted authorization outcomes:** map a second identity/device state into VLAN
   130 and verify that authentication success is distinct from authorization policy.
5. **Hinted roaming:** align mobility-domain/FT parameters on AP1/AP2, trigger a
   roam, and compare a normal roam with an FT roam using wpa_supplicant and hostapd logs.
6. **Open client incident:** given “credentials work elsewhere, but this device
   cannot join,” determine whether failure occurs at discovery, association, EAP,
   certificate validation, RADIUS authorization, DHCP, or policy.
7. **Break-It:** rotate the RADIUS/EAP server certificate to one signed by an
   untrusted lab CA. The AP remains up, the SSID remains visible, and guest works,
   but corporate clients reject the server. Diagnose from the client and RADIUS
   perspectives; install the intended trust chain rather than disabling validation.
8. **RF evidence case:** analyze provided survey CSV/JSON, AP/client event logs,
   spectrum screenshots created for the repo, and a capture to distinguish weak
   coverage, high utilization, CCI, a sticky client, and an authentication fault.

## Make the invisible visible

- Capture association/authentication frames on the virtual radio path.
- Show hostapd station state and wpa_supplicant state transitions.
- Correlate RADIUS Access-Request/Challenge/Accept with the assigned VLAN.
- Measure roam interruption and show key-management log differences.
- In evidence mode, require a written evidence chain; do not generate fake live
  RSSI counters.

## Automated checks

`check.sh` must assert at minimum:

1. Both AP management sessions are healthy.
2. Both enterprise and guest SSIDs are active.
3. Corporate station associates and completes approved EAP.
4. Corporate station lands in VLAN 110 and gets correct DHCP/DNS.
5. Quarantine identity lands in VLAN 130.
6. Guest station lands in VLAN 120.
7. Guest reaches internet-test but cannot reach corp/RADIUS/AP management.
8. Corporate reaches approved internal service.
9. Corporate cannot bypass its assigned policy with a static address.
10. Roam station transitions APs and keeps/re-establishes connectivity within the measured bound.
11. Server-certificate validation is enabled in golden state.
12. No virtual PHY/process/bridge artifact remains after destroy.

If live 802.11r is supported, assert its event evidence. If not, omit the live claim
and validate only the evidence exercise.

## Evidence-pack rules

Store repo-created, license-safe material under
`labs/fixtures/wireless-core-operations/` with provenance and SHA-256 checksums.
Every artifact must be marked “captured live,” “generated from this lab,” or
“synthetic evidence.” Provide an answer key only in a collapsed solution/proctor file.

## Planned files and docs

- Full standard lab files plus `radio-setup.sh`, `radio-cleanup.sh`, `PROBE.md`,
  `VALIDATION.md`, PKI scaffolding, and checked fixture manifests.
- `docs/tracks/enterprise/wireless-core-operations.md`.
- Update Enterprise, Security, and Troubleshooting study paths without replacing
  the original architecture lab.
- Document kernel/module prerequisites and an explicit unsupported-host path.

## Resource target

- 1 cEOS + 7 lightweight Linux nodes.
- Steady state ≤ 4 GiB; peak ≤ 6 GiB.
- Clean radio teardown is a release-blocking requirement.

## Definition of done

In addition to master gates: three consecutive clean deploy/destroy cycles leave
zero radio artifacts; certificate rejection is reproduced without exposing a
“disable validation” shortcut; corp/guest/quarantine negative tests pass; roam
claims match measured logs; RF artifacts are provenance-labeled and reviewed by a
second person before public release.
