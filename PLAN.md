# Gap-Closure Plan (CCNP + Broad Enterprise IT)

> **Purpose of this file:** working roadmap and resume point for closing the gaps
> identified in the June 2026 curriculum review ("can this repo train a CCNP-level,
> broad enterprise engineer?"). If you (human or agent) are picking this up cold:
> statuses below are the source of truth. Update a checkbox + the Status Log when a
> deliverable merges to main, not before. One branch + PR per deliverable; **never
> stack branches** (a stacked-branch merge race previously lost a lab from main).
> Definition of done for any lab: clean-state deploy → run every README verification
> command → run break-it steps → destroy → deploy again.

## Review findings being addressed (summary)

1. No statement of platform fidelity (FRR/cEOS vs IOS-XE exam syntax) anywhere in docs.
2. Wireless RF and SD-Access/SD-WAN are ENCOR blueprint holes (~20% combined).
3. Automation hands-on is thinner than ENCOR expects (no Python/REST/NETCONF lab).
4. The three tracks (networking / SOC / EIT101) never converge — no integration capstone.
5. Smaller holes: no load-balancer lab, no Windows-reality notes in EIT101, no IPv6 in
   EIT101, no named pre-CCNA on-ramp.
6. No exam-topic coverage map → gaps are invisible/accidental rather than intentional.
7. EIT101 Labs 13–16 (monitoring, SIEM, backup, capstone) designed but unbuilt.

---

## Phase 1 — Honesty docs and coverage map (no infrastructure)

- [x] **1.1 `docs/coverage-map.md`** — matrix of ENCOR 350-401 + ENARSI 300-410 exam
      topics → labs. Statuses per row: covered / covered conceptually (syntax differs) /
      not covered (see study notes). Fetch the real Cisco blueprints; don't work from
      memory. This map is the acceptance test for Phases 2–4.
- [x] **1.2 Scope & fidelity doc** — section in `docs/study-paths.md` (or standalone page
      linked from the CCNP path): what FRR/cEOS teaches vs what IOS-XE exams test
      (named EIGRP, MQC QoS, HSRP/GLBP, Cisco NHRP syntax, DNA Center/vManage);
      recommended exam-prep bridge (CML/Boson pass after the labs).
- [x] **1.3 Pre-CCNA on-ramp** — named sequence in `docs/study-paths.md`:
      `vlan-trunks-switchport-basics → two-routers → packet-analysis-basics → …`
      with a "start here if subnetting/ARP are shaky" pointer.

## Phase 2 — Cheap blueprint fills (one lab each; independent, parallelizable)

- [x] **2.1 `labs/automation-fundamentals`** — cEOS pair + automation container. Student
      writes Python against eAPI (optionally gNMI via pygnmi): GET structured state,
      parse JSON, idempotent change, verify. Challenge questions compare REST vs
      NETCONF/RESTCONF semantics. Reuse `network-automation-netbox` image patterns.
- [x] **2.2 `labs/load-balancer-basics`** — HAProxy or nginx + two backends behind the
      `enterprise-dmz` pattern: L4 vs L7, health checks, X-Forwarded-For, asymmetric
      return-path break-it exercise.
- [x] **2.3 `labs/sdwan-concepts`** (reference-style) — two branches, two transports
      (simulated MPLS + internet), policy path selection with IP SLA tracking; README
      maps each manual step to what vManage/vSmart automates. Also: append a curated
      RF/wireless theory reading list to `labs/enterprise-wireless-architecture/README.md`.

New labs: use the `/new-lab` skill, then audit output against `labs/AUTHORING.md`
(band ratios guided ≤20% / hinted ~60–70% / open ~15–20%, required README sections —
the skill predates the authoring contract).

## Phase 3 — Finish Enterprise IT 101 (serial; cumulative state)

Follow `enterprise-it-101/AUTHORING.md` + `DESIGN.md`; keep base+override compose layering.

- [x] **3.1 Lab 13 — Monitoring** (Prometheus/Grafana or Zabbix per DESIGN.md against
      the existing stack).
- [x] **3.2 Lab 14 — SIEM/logging.** Decided: keep ecosystems separate (soc-elk
      ships only a mock store; nothing real to reuse). Built `labs/14-siem-logging`
      with a real Wazuh manager + agents. Done.
- [ ] **3.3 Lab 15 — Backup & recovery.**
- [ ] **3.4 Lab 16 — Capstone.**
- [ ] **3.5 EIT101 reality notes** — "Samba vs Windows AD in the real world" table in
      `enterprise-it-101/README.md` (PowerShell/RSAT equivalents per lab); decide IPv6:
      small exercise in Lab 05/06 or explicit out-of-scope note.

## Phase 4 — Cross-track grand capstone (the crown jewel)

- [ ] **4.0 PROTOTYPE FIRST (load-bearing unknown):** bridge a ContainerLab topology to
      the Docker Compose `lab-corp` network in a throwaway topology. Likely a clab
      `bridge`/`host` node attached to the compose network. If ugly → fallback: re-host
      needed EIT101 services (dc1, radius, kea) as ContainerLab nodes reusing EIT101
      images, accepting duplication for the capstone only. Record outcome here.
- [ ] **4.1 `labs/enterprise-grand-capstone`** (or top-level `capstone/` if both tooling
      stacks are needed): `enterprise-campus` topology whose access layer carries real
      EIT101 services — 802.1X against FreeRADIUS→AD (EIT101 Lab 12), DHCP relay to Kea
      with DDNS into Samba DNS, DMZ/firewall policy for mail gateway + proxy.
- [ ] **4.2 Troubleshooting finale** — 3–4 planted cross-layer faults (e.g. a routing
      problem that presents as "Kerberos is broken").
- [ ] **4.3 Update `docs/coverage-map.md` + `docs/study-paths.md`** with everything
      added in Phases 2–4.

Dependencies: 4.1 needs 4.0 and benefits from Phase 3 complete. Phases 1 and 2 are
independent of everything.

---

## Status log

| Date | Item | Status / notes |
|------|------|----------------|
| 2026-06-11 | Plan created | Review delivered; no phases started. |
| 2026-06-11 | 1.1 coverage map | Merged (PR #10). Built against ENCOR 350-401 **v1.2** (2025) + ENARSI 300-410 v1.1. **Finding: ENCOR v1.2 dropped the wireless domain entirely** — review finding #2's "wireless RF ~20% hole" is stale; SD-WAN/SD-Access + automation gaps remain. |
| 2026-06-11 | 1.2 fidelity doc | Merged (PR #11). "Platform fidelity" section in docs/study-paths.md; anchor is linked from coverage-map.md. |
| 2026-06-11 | 1.3 pre-CCNA on-ramp | Merged (PR #12). **Phase 1 complete.** Next: Phase 2 (2.1–2.3 are independent/parallelizable). |
| 2026-06-12 | 2.1 automation-fundamentals | Merged (PR #14). **⚠ live cEOS walk-through still owed**: no `ceos:4.35.2F` image on the Mac and the lab host (192.168.0.26) rejects key auth, so solutions were validated against a stateful mock eAPI only — exact EOS JSON key paths (`interfaceAddress.ipAddr`, `peerState`, `routes`) unverified on real cEOS. Run the README end to end on the lab host and fix any drift. Coverage map rows 4.6/5.3/6.1/6.2/6.5 updated. |
| 2026-06-12 | 2.2 load-balancer-basics | Merged (PR #15). Fully validated live (containerlab-in-docker on the Mac works — see memory): all solutions executed, asymmetric-return break-it confirmed by capture, check.sh 12/12, clean redeploy. No licensed images. |
| 2026-06-12 | 3.1 Lab 13 monitoring | Merged (PR #18). Prometheus/Grafana/Alertmanager/blackbox + node-exporter sidecars over the real AD+mail services; fully validated live (two down-v/up cycles, alert pipeline to webhook, both break-it drills). `workstation:local` gained jq+python3. Next: 3.2 Lab 14 SIEM — decide soc-elk reuse vs separate stack and record here. |
| 2026-06-12 | 2.3 sdwan-concepts + RF reading list | Merged (PR #16). Fully validated live; brownout demo (netem 150ms, monitor silent) is the SLA lesson. Found during validation: kernel flushes static underlay routes on link flap — pathmon re-pins each cycle. **Phase 2 complete** (modulo the 2.1 cEOS pass above). Next: Phase 3 (serial, EIT101) or Phase 4 prototype 4.0. |
| 2026-06-12 | 3.1 Lab 13 monitoring | Merged (PR #18). Prometheus/Grafana/Alertmanager/blackbox; see memory for techniques. |
| 2026-06-12 | 3.2 Lab 14 SIEM | Built `labs/14-siem-logging` (branch `lab/eit101-siem`). Real Wazuh manager 4.14.5 + agents (no indexer/dashboard — memory ceiling; dashboard is an optional appendix). Two derived images (`samba-ad-wazuh`, `workstation-wazuh`). **Fully validated on a clean down-v/up walk**: enroll (wazuh-control, not systemctl), SSH brute-force 5763 (after onboarding auth.log), Samba JSON audit custom rules 100201/100202/100210, new-user audit only on NETWORK create (break-it), firewall-drop active response → iptables DROP, realtime FIM. PR pending. Next: 3.3 Lab 15 backup. |
