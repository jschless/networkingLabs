# Routed EVPN Data-Center Interconnect — Practice Lab

Connect independent Site A and Site B EVPN fabrics with a routed DCI. The core
exercise is to exchange PROD type-5 routes and shared services while retaining
DEV within each site; the Break-It is a healthy EVPN session with a bad import RT.

## Topology

```text
 a-client -- a-leaf -- a-spine -- a-bgw ===== b-bgw -- b-spine -- b-leaf -- b-app
                  \                         DCI                         /     \
                   \-- a-app (shared service)                     b-client PROD/DEV
```

| Tenant | VLAN/L2VNI | L3VNI | Site A | Site B | DCI policy |
|---|---:|---:|---|---|---|
| PROD | 10 / 10010 | 50010 | `172.16.10.0/24` | `172.17.10.0/24` | type-5 exchange |
| DEV | 20 / 10020 | 50020 | `172.16.20.0/24` | `172.17.20.0/24` | local only |
| Shared | 30 | PROD 50010 | `172.31.10.10` | imported into PROD | no DEV access |

| Link | Purpose |
|---|---|
| `a-leaf:a-spine`, `a-spine:a-bgw` | Site A routed underlay and local EVPN propagation |
| `b-leaf:b-spine`, `b-spine:b-bgw` | Site B routed underlay and local EVPN propagation |
| `a-bgw:b-bgw` | Routed DCI: eBGP IPv4 reachability plus EVPN NLRI exchange |
| `a-client:a-leaf`, `a-app:a-bgw`, `b-client:b-leaf`, `b-app:b-bgw` | Tenant endpoint attachments |

Site-A underlay links use `10.11.0.0/16`, Site B uses `10.21.0.0/16`, and
the routed DCI is `10.255.10.0/30`. Border gateways participate in the local
PROD L2VNI and L3VNI; this is required for local endpoint MAC resolution.

| Node | Role |
|---|---|
| `a-leaf`, `b-leaf` | Tenant leaf/VTEP and first-hop anycast gateway |
| `a-spine`, `b-spine` | eBGP fabric transit and EVPN route-reflection-free propagation |
| `a-bgw`, `b-bgw` | Local PROD VTEP, border gateway, and DCI peer |
| `a-client`, `b-client` | Dual-homed-in-concept PROD/DEV test clients |
| `a-app`, `b-app` | Site-local shared-service and PROD application endpoints |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an objective and
hints; produce the configuration before opening the answer key.

- **Predict before you configure.** Commit to an answer before changing the CLI.
- **Open hints before solutions.** Solutions are for checking or getting unstuck.
- **Verify like an operator.** Use state and data-plane evidence after every task.

## Deploy

```bash
docker build -t dci-endpoint:local -f labs/dci-evpn-multisite/Dockerfile.endpoint labs/dci-evpn-multisite/
./scripts/lab.sh deploy dci-evpn-multisite
./scripts/lab.sh cli dci-evpn-multisite a-bgw
```

The lab uses `ceos:4.35.2F` and `dci-endpoint:local`, built from pinned
`alpine:3.22.1`. Site-local fabric state is prebuilt; DCI peer, remote RTs,
underlay reachability, and DCI route policy are intentionally absent.

## Task 1 — Validate each local fabric

**Objective:** Prove local underlay, EVPN, anycast gateway, and local PROD
service before configuring DCI.

**Predict first:** Can `a-client` reach `172.17.10.10` yet, and which missing
plane prevents it?

<details markdown="1">
<summary>Hints</summary>

- Compare `show bgp summary` on each leaf and border.
- `a-client` reaches `172.31.10.10`; `b-client` reaches `172.17.10.10`.

</details>

<details markdown="1">
<summary>Solution</summary>

No configuration is needed. Local addressing, EVPN sessions, and endpoint routes
are prebuilt; this is the one guided observation task.

</details>

<details markdown="1">
<summary>Check your work</summary>

`show bgp summary` shows local `L2VPN EVPN` Established. `show ip route vrf PROD`
does not yet contain the remote site prefix; the DCI control and forwarding planes
are deliberately absent.

</details>

## Task 2 — Establish the routed DCI

**Objective:** Form eBGP EVPN between `a-bgw` (AS 65012) and `b-bgw` (AS 65022)
and make remote VTEP loopbacks reachable through the underlay.

**Predict first:** Why do `10.10.0.0/24` and `10.20.0.0/24` routes belong in the
default underlay rather than PROD?

<details markdown="1">
<summary>Hints</summary>

- DCI neighbors are `10.255.10.1` and `.2`; activate IPv4 and EVPN and send extended communities.
- Site A routes `10.20.0.0/24` leaf → spine → border → DCI; mirror the path at Site B.

</details>

<details markdown="1">
<summary>Solution</summary>

```text
! Site A leaf / spine / border respectively
ip route 10.20.0.0/24 10.11.0.2
ip route 10.20.0.0/24 10.11.0.5
ip route 10.20.0.0/24 10.255.10.2
! Mirror Site B toward 10.10.0.0/24 via .2, .5, and 10.255.10.1

router bgp 65012
 neighbor 10.255.10.2 remote-as 65022
 neighbor 10.255.10.2 send-community extended
 address-family ipv4
  neighbor 10.255.10.2 activate
 address-family evpn
  neighbor 10.255.10.2 activate
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The border reports an Established `L2VPN EVPN` DCI session. A VTEP ping such as
`ping 10.20.0.1 source 10.10.0.1` proves the outer VXLAN destination is reachable.

</details>

## Task 3 — Exchange PROD type-5 routes only

**Objective:** Import remote PROD RTs at both the local border and leaf, then
filter DCI exports so DEV type-5 routes cannot cross.

**Predict first:** If only the border imports the remote RT, can a leaf endpoint
use the route?

<details markdown="1">
<summary>Hints</summary>

- Site A imports `65020:50010` at `a-bgw` and `a-leaf`; Site B imports `65010:50010` at both roles.
- Match the local PROD RT with `ip extcommunity-list`, permit it in a route map, then deny unmatched exports.

</details>

<details markdown="1">
<summary>Solution</summary>

```text
! a-bgw
ip extcommunity-list DCI-PROD permit rt 65010:50010
route-map DCI-PROD permit 10
 match extcommunity DCI-PROD
route-map DCI-PROD deny 20
router bgp 65012
 neighbor 10.255.10.2 route-map DCI-PROD out
 vrf PROD
  route-target import evpn 65020:50010
! a-leaf, router bgp 65011 / vrf PROD
 route-target import evpn 65020:50010
! Site B mirrors this with local RT 65020:50010 and remote RT 65010:50010.
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`show ip route vrf PROD 172.17.10.0/24` at `a-leaf` shows VTEP `10.20.0.1`,
VNI `50010`. `show ip route vrf DEV` contains no remote DEV subnet.

</details>

## Task 4 — Make the DCI visible

**Objective:** Prove remote PROD and shared-service access while proving DEV
isolation and observing the real DCI data plane.

**Predict first:** Is `b-client → a-app` a VLAN stretch or a routed type-5 path?

<details markdown="1">
<summary>Hints</summary>

- Run PROD pings to `172.17.10.10` and `172.31.10.10`.
- Use `ping -I 172.16.20.10` to test DEV without its PROD default route.
- Capture `udp port 4789` on `a-bgw:eth2`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./scripts/lab.sh bash dci-evpn-multisite a-bgw
tcpdump -nli eth2 udp port 4789
```

Generate a remote PROD ping while capture runs.

</details>

<details markdown="1">
<summary>Check your work</summary>

The capture reports VNI 50010. The PROD FIB maps the prefix to a remote VTEP;
DEV sourced pings fail because no remote DEV FIB is installed.

</details>

## Task 5 — Test the DCI failure domain

**Objective:** Shut the DCI link and distinguish inter-site loss from healthy
site-local EVPN service.

**Predict first:** Which of `a-client → a-app` and `a-client → b-app` survives?

<details markdown="1">
<summary>Hints</summary>

- Shut `a-bgw Ethernet2`, compare the DCI BGP summary and PROD FIB, then restore it.

</details>

<details markdown="1">
<summary>Solution</summary>

```text
configure
interface Ethernet2
 shutdown
end
! Restore with: no shutdown
```

</details>

<details markdown="1">
<summary>Check your work</summary>

Remote type-5 service withdraws but Site A shared-service reachability remains.
That is the routed DCI fault boundary.

</details>

## Task 6 — Choose routing or L2 extension

**Objective:** Defend a workload-migration design without configuring a feature
that has not been validated here.

**Predict first:** What additional MAC-mobility, BUM, and failure-domain evidence
would make an L2 stretch acceptable?

<details markdown="1">
<summary>Hints</summary>

- Compare type-5/FIB evidence with local L2VNI state. This lab does not claim live L2 stretch, ESI, or BUM containment.

</details>

<details markdown="1">
<summary>Solution</summary>

There is no required CLI answer. Record a routed-border design, name the migration
constraint that would require L2, and list the additional evidence required.

</details>

<details markdown="1">
<summary>Check your work</summary>

Your design explains why the current RT policy preserves DEV isolation and why it
does not validate stretched-L2 behavior.

</details>

## Task 7 — Break-It: wrong import RT

**Objective:** Diagnose Site B receiving a healthy PROD type-5 NLRI while failing
to install it in PROD, then make the smallest repair.

**Predict first:** Which changes first: the EVPN table or the PROD FIB?

<details markdown="1">
<summary>Hints</summary>

- Start from `b-client` failing to reach `172.16.10.10` with all sessions Established.
- Compare `show bgp evpn route-type ip-prefix` and `show ip route vrf PROD 172.16.10.0/24` on `b-leaf`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./labs/dci-evpn-multisite/break-it.sh
./labs/dci-evpn-multisite/check.sh       # expected failure
./labs/dci-evpn-multisite/repair-break-it.sh
./labs/dci-evpn-multisite/check.sh       # pass
```

The repair is `route-target import evpn 65010:50010` under `router bgp 65021`,
`vrf PROD` on `b-leaf`.

</details>

<details markdown="1">
<summary>Check your work</summary>

The NLRI stays visible but the FIB disappears with RT `65010:59999`; after repair,
the VTEP route and endpoint service return while DEV remains isolated.

</details>

## Verification

```bash
./scripts/lab.sh check dci-evpn-multisite
```

## Challenge questions

1. What evidence would justify a second DCI link and ECMP?
2. How would a third site avoid importing the shared-service RT accidentally?
3. How do you distinguish a wrong RT from a remote-VTEP underlay failure?
4. When does a migration justify L2 extension despite its larger fault domain?

## Troubleshooting

**BGP is Established but the remote PROD route is absent** — compare the EVPN
NLRI and VRF FIB, then inspect import RTs at both border and leaf.

**VTEP route exists but traffic fails** — verify leaf/spine/border underlay paths
to the remote loopback and capture UDP/4789 on the DCI.

**Linux endpoint receives a request but does not reply** — its management default
route won. The supplied setup scripts use `ip route replace default ... dev eth1`.

## Extensions

L2 stretch, MAC mobility, duplicate-MAC handling, BUM containment, ESI/MLAG,
BFD, and dual-DCI ECMP are intentionally unvalidated and out of scope.
