# Topic Quiz — DMVPN

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `dmvpn-phase1`, `dmvpn-phase2`, and `dmvpn-phase3`.

Configuration syntax is VyOS as used by the labs.

---

## Section 1 — Mechanisms (4 points)

### A1 — Three phases, two kinds of scaling

For DMVPN Phases 1, 2, and 3, state the spoke-to-spoke data path and whether spokes need
full remote route detail or may rely on a hub summary. Name the NHRP behavior that enables
direct forwarding. (4 pts)

---

## Section 2 — Evidence reading (6 points)

### B1 — A specific appears after traffic

Before traffic, spoke1 has only:

```text
O E2 192.168.0.0/16 via 172.16.0.1, tun0
```

After the first packet toward `192.168.2.10`:

```text
NHRP 192.168.2.0/24 via 172.16.0.12, tun0
NBMA mapping 172.16.0.12 -> 10.0.0.12
```

1. Identify the DMVPN phase and explain the first-packet and later-packet paths. (3 pts)
2. Why does the /24 override the /16 without changing OSPF preference? (1 pt)
3. What happens to reachability and path efficiency if `shortcut` is removed from
   spoke1? (2 pts)

---

## Section 3 — Application (5 points)

### C1 — Phase 3 spoke essentials

Write the essential VyOS commands for spoke1 to:

- use NHRP network ID 1 on `tun0`;
- register with NHS tunnel IP `172.16.0.1` at NBMA `10.0.0.1`;
- map multicast to the hub and enable shortcuts;
- run OSPF point-to-multipoint on `tun0`;
- advertise tunnel `/32` `172.16.0.11/32` and LAN `192.168.1.0/24`.

Router ID is `10.0.0.11`. Omit holdtime and save/commit commands.

---

## Section 4 — Troubleshooting (5 points)

### D1 — The hub is not always in the data path

The hub fails after spoke1 already built a shortcut to spoke2, but before it has ever
contacted spoke3. Predict both conversations immediately after failure and after the
existing shortcut ages out. Name the control-plane dependency and two checks that prove
your explanation. (5 pts)

---

<!-- site-include-end -->

*End of DMVPN quiz. Key:
[`../answer-keys/quizzes/dmvpn-key.md`](../answer-keys/quizzes/dmvpn-key.md).*
