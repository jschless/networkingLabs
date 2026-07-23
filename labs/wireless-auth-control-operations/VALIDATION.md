# Validation Record — `wireless-auth-control-operations`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-23, WP-02 worker |
| Host OS/kernel | Ubuntu Linux `5.15.0-181-generic` x86_64 |
| ContainerLab/Docker versions | `0.74.1` / client and server `29.5.3` |
| Image tags/digests | `wireless-auth-control:local` built from `debian:12.12-slim@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c` |
| Repository commit | `e8d4297` (based on `origin/main` `97d4e27`) |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Image build | `docker build -t wireless-auth-control:local labs/wireless-auth-control-operations` succeeded | 27.10 s initial cached-base build | build max RSS 55,856 KiB |
| Deploy | `./scripts/lab.sh deploy wireless-auth-control-operations` created eight Linux nodes and seven scoped links | 6.30 s | 54.5 MiB summed steady container memory |
| Healthy/check | `./labs/wireless-auth-control-operations/check.sh` passed all 17 assertions | after 10 s EAP readiness | 54.5 MiB steady |
| Break-It failure | `break-it.sh`; check failed corporate EAP success, VLAN 110 projection, and corporate reachability as intended; guest policy still passed | 10 s wait | 54.5 MiB steady |
| Minimal repair/check | `repair-break-it.sh`; restart only the trusted RADIUS service and corp/quarantine supplicants; all 17 assertions passed | 10 s wait | 54.5 MiB steady |
| Destroy/cleanup | `./scripts/lab.sh destroy wireless-auth-control-operations` plus `radio-cleanup.sh` | 1.95 s | no current-lab containers, links, or virtual PHY |
| Redeploy/recheck/destroy | clean redeploy passed all 17 checks after 10 s EAP readiness; final scoped destroy completed | deploy 5.50 s; final destroy 1.95 s | under 4 GiB target |

## Positive and negative evidence

- Positive: FreeRADIUS 3.2.1 and two hostapd wired authenticators ran; corp and
  quarantine EAP-TLS emitted `CTRL-EVENT-EAP-SUCCESS`; RADIUS Access-Accept
  carried VLAN 110/130; bridge ports projected to the matching VLANs; corp,
  guest, and quarantine reached only their intended services.
- Negative: corp could not reach guest; guest and quarantine could not reach
  corporate; the Break-It untrusted server certificate caused corporate EAP
  failure and removed VLAN 110 reachability without changing the client trust
  settings.

## Repository gates

The following are run after final documentation edits and recorded in the PR:

```text
python3 scripts/lint-labs.py
./scripts/check-docs-admonitions.sh
mkdocs build --strict
shellcheck -S warning scripts/*.sh labs/*/check.sh
```

## Limitations, refresh, and cleanup

- **Unsupported/evidence-only:** host-side `mac80211_hwsim` load was blocked by
  non-interactive sudo; association, four-way handshake, roaming/802.11r, RF
  measurements, DFS, and real controller behavior are not claimed. See
  `PROBE.md` and `labs/fixtures/wireless-core-operations/MANIFEST.md`.
- **Image refresh:** Debian `12.12-slim` digest was pulled and built on
  2026-07-23. Debian package versions observed in the build include FreeRADIUS
  `3.2.1+dfsg-4+deb12u1` and hostapd/wpa_supplicant `2:2.10-12+deb12u3`.
  No vulnerability scanner is installed on this host; review this pinned base
  and package set at the next monthly refresh.
- **Residual artifacts:** scoped ContainerLab destroy removes only this lab's
  containers, links, hosts entry, SSH config, and generated lab directory;
  `radio-cleanup.sh` confirms no fallback-created virtual PHY. No broad Docker
  or module cleanup is used.
- **Follow-up:** repeat the full WP-02 virtual-radio probe on a host with a
  reviewed non-interactive hwsim load/unload permission before attempting the
  original `wireless-core-operations` fidelity target.
