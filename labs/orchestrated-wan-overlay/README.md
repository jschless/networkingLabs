# Orchestrated WAN Overlay — Practice Lab

This level-4 practice lab builds a provider-neutral, orchestrated WAN overlay with
a controller, a separate PKI, mTLS-enrolled Linux edges, WireGuard tunnels, two
underlays, segmentation, policy/version acknowledgement, and SLA steering. It is
not Cisco Catalyst SD-WAN, vManage, vSmart, or a vendor product workflow.

## Topology

```text
                     [PKI]---[controller]
                        \     control / mTLS
                         +---[control LAN]
                                 | hub |
corp1--branch1 == MPLS/private ==+     +== MPLS/private == branch2--corp2
guest1   ||       internet       |     |       internet       ||     guest2
         +=======================+     +======================+
                                   | private-app
                      guest/SaaS local breakout -- internet -- saas
```

| Plane | Addresses | Purpose |
|---|---|---|
| CORP | `10.113.10.0/24`, `10.113.20.0/24`, `10.113.30.0/24` | Encrypted route exchange |
| Control | `10.113.40.0/24` | PKI and controller mTLS API |
| MPLS/private | `/30`s in `172.20.113.0/24` | First transport and SLA probe |
| Internet | `/30`s in `192.0.2.112/28` | Second transport and breakout |
| Overlay | `10.255.113.0/24` | WireGuard tunnel identities |
| GUEST | `10.113.110.0/24`, `10.113.120.0/24` | Local breakout; no private service |

| Running component | SD-WAN concept it represents |
|---|---|
| controller desired version, audit, edge acknowledgement | manager/controller plus policy controller |
| PKI CSR signing and revocation serial list | enterprise CA/trust lifecycle |
| edge reconciliation agent | bootstrap/control agent |
| WireGuard per-transport interfaces | encrypted overlay/TLOC-like transport |
| loss/latency probe and hold-down | BFD/SLA/app-route decision |

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an **objective** and
**hints** — your job is to produce the configuration.

- **Predict before you configure.** Commit to an answer before touching the CLI.
- **Open the hints before the solution.** The solution toggle is an answer key.
- **Verify like an operator.** Prove state with show commands before moving on.

## Deploy

```bash
docker build -t orchestrated-wan-tools:1.0.0 labs/orchestrated-wan-overlay/
./scripts/lab.sh deploy orchestrated-wan-overlay
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- ping -c1 172.20.113.5
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- ping -c1 192.0.2.116
```

These prove only the two underlays. No edge is enrolled and no overlay route exists at startup.

## Task 1 — Survey the planes (guided)

**Objective:** Prove both branch1 underlays work while the private app is absent.

**Predict first:** Can `corp1` reach `10.113.30.10` before any trusted edge enrolls?

```bash
./scripts/lab.sh cmd orchestrated-wan-overlay corp1 -- ping -c1 -W1 10.113.30.10
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- ip -br addr
```

**Check your work:** The first command fails; `eth1` is control, while `eth2` and
`eth3` are independent transport underlays.

## Task 2 — Enroll trusted edges (hinted)

**Objective:** Issue identities for `hub`, `branch1`, and `branch2`, then start their controller agents.

**Predict first:** What response should `CN=unknown-edge` receive from this PKI?

<details markdown="1"><summary>Hints</summary>

- Create a private key and CSR on each edge; only the three known edge names are signed.
- Install the CA before making the mTLS policy request.
- The helper does enrollment mechanics, not route policy.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
for edge in hub branch1 branch2; do
  ./scripts/lab.sh cmd orchestrated-wan-overlay "$edge" -- bash /enroll.sh
done
```

</details>

<details markdown="1"><summary>Check your work</summary>

```bash
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- openssl verify -CAfile /runtime/edges/branch1/ca.crt /runtime/edges/branch1/client.crt
./scripts/lab.sh cmd orchestrated-wan-overlay controller -- curl -ks https://10.113.40.10:8443/v1/status
```

The certificate verifies to the PKI CA and controller `applied_version` appears only
after a trusted policy pull. An unknown CSR is rejected.

</details>

## Task 3 — Establish encrypted CORP routes (hinted)

**Objective:** Reconcile the centrally supplied overlay and exchange CORP routes without GUEST leakage.

**Predict first:** Which interface should carry `10.113.30.0/24` in golden state?

<details markdown="1"><summary>Hints</summary>

- Inspect `wg show` and controller status separately.
- `ip route get` proves forwarding, not trust.
- Test GUEST to the private app as a negative case.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- wg show
./scripts/lab.sh cmd orchestrated-wan-overlay corp1 -- ping -c2 10.113.20.10
./scripts/lab.sh cmd orchestrated-wan-overlay guest1 -- ping -c1 -W1 10.113.30.10
```

</details>

<details markdown="1"><summary>Check your work</summary>

CORP reaches the remote site through hub-routed WireGuard tunnels. GUEST fails at edge
segment policy before it can use a private route.

</details>

## Task 4 — Publish and roll back policy (hinted)

**Objective:** Publish `v2`, observe acknowledgements, then roll back to `v1` without service loss.

**Predict first:** Is desired controller version evidence that every edge applied it?

<details markdown="1"><summary>Hints</summary>

- Desired state and edge applied state are different fields.
- Use the audit and `/v1/status` after each transition.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd orchestrated-wan-overlay controller -- python3 /controllerctl.py publish v2
sleep 3
./scripts/lab.sh cmd orchestrated-wan-overlay controller -- python3 /controllerctl.py rollback v1
```

</details>

<details markdown="1"><summary>Check your work</summary>

Desired and applied versions converge to `v1`; `corp1` still reaches the private app.

</details>

## Task 5 — Observe SLA steering and local breakout (hinted)

**Objective:** Verify critical private traffic prefers MPLS while SaaS and GUEST use internet breakout.

**Predict first:** Does one missed probe immediately switch the critical path?

<details markdown="1"><summary>Hints</summary>

- Critical private traffic is TCP/8443 to `10.113.30.10`; inspect table `100`.
- The agent requires three bad samples, five good samples, and a 15-second hold-down.
- GUEST can reach `10.113.50.10:8080`, never the private app.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- ip route show table 100
./scripts/lab.sh cmd orchestrated-wan-overlay guest1 -- curl -fsS http://10.113.50.10:8080
./scripts/lab.sh cmd orchestrated-wan-overlay controller -- curl -ks https://10.113.40.10:8443/v1/status
```

</details>

<details markdown="1"><summary>Check your work</summary>

Table `100` selects `wg-mpls-hub`; controller status shows probe health and the chosen
path separately from tunnel and route state.

</details>

## Task 6 — Tune a brownout without oscillation (open)

**Objective:** Inject loss or >80 ms latency on branch1 MPLS, measure bounded failover, then remove it.

**Predict first:** Why should one transient probe not move the critical path?

<details markdown="1"><summary>Hints</summary>

- Apply `tc netem` to `branch1:eth2` and inspect status once per second.
- Remove only your qdisc; do not disable TLS or the agent.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- tc qdisc add dev eth2 root netem loss 100%
sleep 8
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- ip route show table 100
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- tc qdisc del dev eth2 root
```

</details>

<details markdown="1"><summary>Check your work</summary>

After three failed samples, critical traffic uses `wg-inet-hub`. Failback needs five
good samples and the hold-down, preventing a single-probe oscillation.

</details>

## Task 7 — Break-It: revoked edge identity (open)

**Scenario:** Underlays still ping, local LAN and SaaS work, but branch1 lost private-app service after a certificate incident.

**Objective:** Diagnose trust/time/control state, revoke branch1, prove the failure, rotate only its identity, and restore policy/route service.

**Predict first:** Why is an underlay ping insufficient evidence of overlay control?

<details markdown="1"><summary>Hints</summary>

- Compare certificate serial/date, controller status, and `wg show`.
- The agent withdraws overlays after three rejected mTLS polls.
- Re-enroll branch1; do not use `-k` or disable certificate validation.

</details>

<details markdown="1"><summary>Solution</summary>

```bash
./scripts/lab.sh cmd orchestrated-wan-overlay pki -- bash /revoke.sh branch1
sleep 4
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- ping -c1 172.20.113.5
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- cat /runtime/edges/branch1/status.json
./scripts/lab.sh cmd orchestrated-wan-overlay branch1 -- bash /enroll.sh
sleep 5
./scripts/lab.sh check orchestrated-wan-overlay
```

</details>

<details markdown="1"><summary>Check your work</summary>

Both underlays remain green while `control` becomes `down` and the overlay is withdrawn.
The new identity re-establishes mTLS, policy acknowledgement, and private service.

</details>

## Verification

```bash
./scripts/lab.sh check orchestrated-wan-overlay
```

## Challenge questions

1. Which controller state should survive restart, and which can be rebuilt from edges?
2. How would you restrict CSR enrollment beyond a permitted common name?
3. What SLA measurements justify changing the 80 ms/three-sample threshold?
4. Where could asymmetric return occur if a second hub were added?

## Troubleshooting

| Symptom | Evidence and minimal repair |
|---|---|
| Underlays ping but private app fails | Compare edge status and certificate serial; rotate with `/enroll.sh`. |
| Tunnel has no handshake | Compare underlay endpoint and `wg show`; do not infer control health from routes. |
| GUEST reaches private service | Inspect edge `nft` forward policy and restore its GUEST deny. |
| Critical path flaps | Inspect bad/good counters and hold-down before changing thresholds. |

## Limitations and fidelity

The lab uses real Linux mTLS, OpenSSL CA signing/revocation, controller API/audit,
WireGuard encryption, route policy, nftables segmentation, and `tc` fault injection.
It does **not** reproduce a commercial UI, OMP/TLOC/BFD wire protocol, carrier MPLS,
application DPI, or vendor licensing workflow. See `PROBE.md` and `VALIDATION.md`.
