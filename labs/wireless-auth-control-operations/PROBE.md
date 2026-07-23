# Feature Probe Record — `wireless-auth-control-operations`

## Scope and decision

- **Feature and learning objective:** prove whether this host can supply four
  `mac80211_hwsim` radios for live 802.11 association, EAP, and roaming.
- **Decision:** documented fallback / rename required.
- **Reason and fidelity statement:** the host kernel has a compatible module,
  but this non-interactive ContainerLab user cannot load it. No simulated PHY was
  created, so namespace placement, hostapd/wpa_supplicant association, EAP over
  802.11, roaming, and teardown cannot honestly be claimed. The WP-02 fallback
  authorizes `wireless-auth-control-operations`: live wired 802.1X/RADIUS
  authorization and VLAN policy, with 802.11/RF/roaming retained as labeled
  evidence analysis only.
- **Owner and date:** WP-02 worker, 2026-07-23.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Ubuntu Linux `5.15.0-181-generic` x86_64 |
| ContainerLab version | `0.74.1` (commit `1866b3a2b`, 2026-03-15) |
| Docker version | client/server `29.5.3` |
| Candidate module | `/lib/modules/5.15.0-181-generic/kernel/drivers/net/wireless/mac80211_hwsim.ko`; radios parameter available |
| Candidate service image | `debian:12.12-slim@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c` |
| Host memory/disk before probe | 15 GiB RAM (12 GiB available); 149 GiB workspace filesystem free |

## Smallest load-bearing test

The probe deliberately stopped before constructing containers: loading the
module is the prerequisite for every later radio/namespace/EAP/roam assertion.
The host's physical `phy0` was observed but not altered.

```text
$ sudo -n modprobe mac80211_hwsim radios=4
sudo: a password is required
modprobe_exit=1

$ iw phy
Wiphy phy0
  ... physical Intel radio capabilities ...

$ cat /sys/module/mac80211_hwsim/parameters/radios
cat: /sys/module/mac80211_hwsim/parameters/radios: No such file or directory
```

Elapsed time was under one second; no containers, virtual PHYs, namespaces,
interfaces, bridge ports, or lab processes were created. Memory and disk use did
not materially change. The required host-side privilege is intentionally not
obtained through a password prompt or an out-of-band privilege escalation.

## Cleanup and repeatability

- **Attempted cleanup:** `sudo -n modprobe -r mac80211_hwsim` returned the same
  password-required result because the module was never loaded.
- **Orphans checked:** `lsmod | rg mac80211_hwsim`, `/sys/module/mac80211_hwsim`,
  `iw phy`, `docker ps`, and `containerlab inspect --all --format json`.
- **Result of a second run:** identical privilege failure; no `mac80211_hwsim`
  module or virtual PHY exists.

## Unsupported behavior and fallback

WP-02 explicitly authorizes this fallback when the virtual-radio probe fails.
The fallback lab does **not** claim live SSID discovery, 802.11 association,
four-way handshake, 802.11r, RF measurements, attenuation, utilization, DFS, or
real client roaming. It does prove live FreeRADIUS EAP server validation,
authorization attributes, wired EAPOL state, VLAN policy projection, and a
certificate-trust incident. To attempt the full lab on another host, grant a
reviewed non-interactive path to load/unload `mac80211_hwsim` and rerun all six
WP-02 probe assertions before changing this decision.
