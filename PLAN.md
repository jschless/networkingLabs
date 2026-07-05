# Gap-Closure Plan (CCNP + Broad Enterprise IT) — COMPLETE, ARCHIVED

> **Status: all four phases finished (June 2026).** This file is kept as a historical
> record of the gap-closure effort, not an active roadmap — don't resume work from it.
> The working conventions it established still apply to new work: one branch + PR per
> deliverable, **never stack branches** (a stacked-branch merge race previously lost a
> lab from main), and the definition of done for any lab remains: clean-state deploy →
> run every README verification command → run break-it steps → destroy → deploy again.
>
> **One known debt carried out of this plan:** item 2.1 (`automation-fundamentals`)
> was validated against a stateful mock eAPI only — a live cEOS walk-through on the
> lab host is still owed (see the 2026-06-12 status-log entry).
>
> Original preamble follows for context.

> **Purpose of this file:** working roadmap and resume point for closing the gaps
> identified in the June 2026 curriculum review ("can this repo train a CCNP-level,
> broad enterprise engineer?").

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
- [x] **3.3 Lab 15 — Backup & recovery.** Built `labs/15-backup-recovery`
      (BorgBackup). Two new images (`backup-server`, `samba-ad-backup`); push +
      volume-style models; both AD and CA disasters recovered live. Done.
- [x] **3.4 Lab 16 — Capstone.** Built `labs/16-capstone`. Merged (PR #22).
- [x] **3.5 EIT101 reality notes** — "Samba vs Windows AD in the real world" table in
      `enterprise-it-101/README.md` (PowerShell/RSAT equivalents per lab); decide IPv6:
      small exercise in Lab 05/06 or explicit out-of-scope note.

## Phase 4 — Cross-track grand capstone (the crown jewel)

- [x] **4.0 PROTOTYPE FIRST (load-bearing unknown):** **PROVED — clab can bridge to the
      compose `lab-corp` network; no fallback needed.** Throwaway test (2026-06-13):
      a clab `bridge`-kind node whose name == the lab-corp Linux bridge, with a router
      node's veth wired into it and a static 10.100.x.x IP → **bidirectional L3 to a
      lab-corp container worked** (same-bridge L2, no iptables/FORWARD interference).
      **Stable bridge name is the key enabler:** set
      `--opt com.docker.network.bridge.name=br-labcorp` on the lab-corp network so the
      clab topology can hard-code the bridge node name (docker's default `br-<id>`
      changes every `compose up`) — base compose must add this driver opt.
      **Transit routing across the boundary also works bidirectionally** (host on a
      separate clab subnet → through the clab router → lab-corp service), with two
      gotchas to design around in 4.1: (a) clab linux nodes default-route via the clab
      **mgmt** net (172.20.20.1), so campus hosts must have their default overridden to
      the campus router, not added-on-top; (b) lab-corp service containers default-route
      to the docker bridge gateway (the host), so return traffic to a campus subnet needs
      either a **host route** (`ip route add <campus> via <router-lab-corp-IP>`, cleanest,
      lab-machine-only) or per-service static routes — or bridge the access subnet so
      hosts sit natively on 10.100.0.0/16 and skip inter-subnet routing entirely.
      Ops note: `containerlab` here is **setuid root** (`-rwsr-xr-x`) → run `containerlab
      deploy/destroy` **without** `sudo` (no passwordless sudo on this host).
- [x] **4.1 `labs/enterprise-grand-capstone`** — BUILT + validated live. Collapsed-core
      cEOS campus + Linux/hostapd access carrying real EIT101 services: 802.1X→FreeRADIUS→AD
      (dynamic VLAN), DHCP relay→Kea with DDNS into BIND (AD forwards to it), seam-ACL
      segmentation, Kerberos. `gcap.sh` orchestrates both stacks over the pinned `br-eitcorp`
      bridge. (mail/proxy SSO left as a documented extension — core integrations all proven.)
- [x] **4.2 Troubleshooting finale** — `faults.sh` injects/clears 4 cross-layer faults
      (F1 routing→Kerberos, F2 RADIUS-secret→802.1X, F3 relay-helper→DHCP, F4 peer-link→VRRP);
      all four validated inject+clear; symptom→hints→cause in README Part B.
- [x] **4.3 Updated `docs/coverage-map.md` + `docs/study-paths.md`** — grand capstone added
      (enterprise-design + AAA rows; cross-track summit section in study-paths).

Dependencies: 4.1 needs 4.0 and benefits from Phase 3 complete. Phases 1 and 2 are
independent of everything.

## Phase 5 — Enterprise operations & services (July 2026 review)

Source: July 2026 pedagogical re-review, this time anchored to "standard enterprise
system + containerlab-testable" rather than exam blueprints. Verified non-gaps first
(NetFlow, MLAG, DAI/snooping, TACACS+, VRF leaking are all already hands-on). Scoped
out by decision (2026-07-05): Kea DHCP-HA lab. Unscheduled second-tier deepenings if
appetite returns: live NAT64 via tayga in `ipv6-transition`, live NETCONF in
`automation-fundamentals`, Oxidized config-backup lab.

All five are independent. Same rules as ever: `/new-lab` skill → audit against
`labs/AUTHORING.md`; never stack branches; definition of done = clean deploy → every
README verification command → break-it steps → destroy → redeploy.
**Branching exception (Joe, 2026-07-05):** 5.1 merged solo (PR #31); **5.2–5.5 all
ride one shared branch/PR** — `lab/ztp-basics` → PR #32. Commit each finished lab to
that branch; merge once when 5.5 lands.

- [x] **5.1 `labs/mpls-ldp`** — LDP-based MPLS on FRR (`ldpd`): OSPF underlay, LDP
      sessions/label bindings, PHP, an LSP end to end; challenge questions contrast
      per-hop LDP state with the `mpls-sr-blank` build. Closes the coverage-map row
      that marks LDP "theory" (ENARSI 2.1 → upgrade to ✅ on merge).
- [ ] **5.2 `labs/ztp-basics`** — day-0 provisioning: factory-default cEOS boots ZTP,
      DHCP option 67 → HTTP config server; break-it: wrong bootfile/unreachable server.
- [ ] **5.3 `labs/anycast-dns`** — routing-on-the-host anycast service: two DNS
      resolvers each advertising the same /32 VIP from FRR-on-the-server into the
      network, health-check withdraws the route on daemon death; closest-resolver +
      failover verified by query + traceroute.
- [ ] **5.4 `labs/k8s-fabric`** — Kubernetes ↔ fabric integration: k3s/kind node(s)
      BGP-peering (Cilium or MetalLB) to a ToR (FRR or cEOS), LoadBalancer Service
      /32s advertised, ECMP across nodes. Lab-host-sized (RAM); prototype the
      k8s-in-container memory footprint before committing to a design.
- [ ] **5.5 `labs/service-ha`** — stateful service HA the way enterprises actually run
      firewall/LB pairs: two nftables (or HAProxy) nodes sharing a keepalived VIP; a
      long-lived TCP flow dies on failover without conntrackd state-sync and survives
      with it. Extends the challenge question at the end of `load-balancer-basics`.
      (Added 2026-07-05 after initially being scoped out; Kea DHCP-HA stays declined.)

---

## Status log

| Date | Item | Status / notes |
|------|------|----------------|
| 2026-07-05 | 5.4 k8s-fabric | Built + fully validated live on branch `lab/ztp-basics` (shared 5.2–5.5 PR #32). **Prototype first (plan-mandated):** k3s-in-containerlab runs privileged by default, Ready ~40s; 2-node cluster + FRR ToR + MetalLB + workload = **~1.4 GB used / 2.3 GB free** on the 3.83 GB VM — comfortable. Design: 2 k3s nodes (server+agent, declarative join via fixed `--token`) on a shared L2 rack segment (racksw bridge) off an FRR ToR; MetalLB BGP mode advertises LoadBalancer /32s → ToR ECMP. **Key traps solved:** (1) clab wires data links AFTER entrypoint starts → k3s entrypoint waits for eth1, addresses it, then `exec`s k3s with `--node-ip`=rack IP (MetalLB advertises node InternalIP as BGP next-hop, so it MUST be the data-plane addr, not mgmt); (2) `k3s kubectl` is wrong — invocation is bare `kubectl`; (3) FRR eBGP default `maximum-paths` is 1 → must set it for ECMP; (4) NEVER `docker rm -f` a running k3s container (wedged the Docker daemon on mount cleanup — had to force-restart Docker Desktop; `docker stop -t 20` first, then rm/destroy). check.sh 11/11 on a clean redeploy; break-it = externalTrafficPolicy Local (node w/o local endpoint withdraws the /32; Cluster SNATs to 10.42.0.1, Local preserves client 172.16.9.10). New pulled image `rancher/k3s:v1.30.6-k3s1` (multi-arch, added to build-images.sh PULLS); MetalLB v0.14.8 manifest vendored; needs internet at deploy. Registered in data-center track. Next: 5.5 service-ha (last of the shared PR). |
| 2026-07-05 | 5.3 anycast-dns | Built + fully validated live on branch `lab/ztp-basics` (shared 5.2–5.5 PR #32). All-FRR routing-on-the-host: 2 routers + 2 FRR+dnsmasq resolvers eBGP-advertising a shared 10.53.53.53/32 via `redistribute connected route-map`; watchdog does route health injection (VIP on lo ⇄ dnsmasq answering). check.sh 17/17 on a clean redeploy; failover measured ~1.8 s; break-it = watchdog-dead blackhole (route up, daemon down, `connection refused`). Traps: dig prints "connection timed out" on STDOUT (health checks must use exit status, not output-emptiness); FRR bare `redistribute connected` does NOT drop an existing route-map binding (remove-then-add); both resolvers auto-pick the VIP as BGP router-id. New image `anycast-dns:local` (FROM frr-lab + dnsmasq/bind-tools); registered in HA track. Next: 5.4 k8s-fabric (prototype memory footprint first). |
| 2026-07-05 | Phase 5 created | July re-review (enterprise-reality lens) added 5.1–5.4; keepalived-HA + Kea-HA labs initially declined. Started 5.1 `mpls-ldp` (branch `lab/mpls-ldp`). Same day: Joe reinstated the keepalived/conntrackd service-HA lab as **5.5**; Kea DHCP-HA remains declined. |
| 2026-07-05 | 5.2 ztp-basics | Built + fully validated live on branch `lab/ztp-basics` (the shared 5.2–5.5 PR). Real cEOS ZTP over the clab mgmt network: option 67 → HTTP fetch → in-container reload; `reset-sw1.sh` wipes flash, re-plumbs the data veths docker-restart destroys, and babysits the Docker-Desktop punt quirk. check.sh 8/8; break-it (404 loop → live fix → self-heal) validated; clean redeploy → blank state. Key traps recorded in memory. Next: 5.3 anycast-dns on the same branch. |
| 2026-07-05 | 5.1 mpls-ldp | Merged (PR #31). Fully validated live: check.sh 11/11, clean redeploy. Validation corrected the break-it lesson — FRR mid-path LDP session loss is a **hard blackhole** (ingress keeps retained stale label; transit LFIB entry deleted), not IP fallback; death takes the 180s hold timer, recovery ~3s. Coverage map ENARSI 2.1 → ✅. Next: 5.2 ztp-basics. |
| 2026-06-11 | Plan created | Review delivered; no phases started. |
| 2026-06-11 | 1.1 coverage map | Merged (PR #10). Built against ENCOR 350-401 **v1.2** (2025) + ENARSI 300-410 v1.1. **Finding: ENCOR v1.2 dropped the wireless domain entirely** — review finding #2's "wireless RF ~20% hole" is stale; SD-WAN/SD-Access + automation gaps remain. |
| 2026-06-11 | 1.2 fidelity doc | Merged (PR #11). "Platform fidelity" section in docs/study-paths.md; anchor is linked from coverage-map.md. |
| 2026-06-11 | 1.3 pre-CCNA on-ramp | Merged (PR #12). **Phase 1 complete.** Next: Phase 2 (2.1–2.3 are independent/parallelizable). |
| 2026-06-12 | 2.1 automation-fundamentals | Merged (PR #14). **⚠ live cEOS walk-through still owed**: no `ceos:4.35.2F` image on the Mac and the lab host (192.168.0.26) rejects key auth, so solutions were validated against a stateful mock eAPI only — exact EOS JSON key paths (`interfaceAddress.ipAddr`, `peerState`, `routes`) unverified on real cEOS. Run the README end to end on the lab host and fix any drift. Coverage map rows 4.6/5.3/6.1/6.2/6.5 updated. |
| 2026-06-12 | 2.2 load-balancer-basics | Merged (PR #15). Fully validated live (containerlab-in-docker on the Mac works — see memory): all solutions executed, asymmetric-return break-it confirmed by capture, check.sh 12/12, clean redeploy. No licensed images. |
| 2026-06-12 | 3.1 Lab 13 monitoring | Merged (PR #18). Prometheus/Grafana/Alertmanager/blackbox + node-exporter sidecars over the real AD+mail services; fully validated live (two down-v/up cycles, alert pipeline to webhook, both break-it drills). `workstation:local` gained jq+python3. Next: 3.2 Lab 14 SIEM — decide soc-elk reuse vs separate stack and record here. |
| 2026-06-12 | 2.3 sdwan-concepts + RF reading list | Merged (PR #16). Fully validated live; brownout demo (netem 150ms, monitor silent) is the SLA lesson. Found during validation: kernel flushes static underlay routes on link flap — pathmon re-pins each cycle. **Phase 2 complete** (modulo the 2.1 cEOS pass above). Next: Phase 3 (serial, EIT101) or Phase 4 prototype 4.0. |
| 2026-06-12 | 3.1 Lab 13 monitoring | Merged (PR #18). Prometheus/Grafana/Alertmanager/blackbox; see memory for techniques. |
| 2026-06-12 | 3.2 Lab 14 SIEM | Built `labs/14-siem-logging` (branch `lab/eit101-siem`). Real Wazuh manager 4.14.5 + agents (no indexer/dashboard — memory ceiling; dashboard is an optional appendix). Two derived images (`samba-ad-wazuh`, `workstation-wazuh`). **Fully validated on a clean down-v/up walk**: enroll (wazuh-control, not systemctl), SSH brute-force 5763 (after onboarding auth.log), Samba JSON audit custom rules 100201/100202/100210, new-user audit only on NETWORK create (break-it), firewall-drop active response → iptables DROP, realtime FIM. Merged (PR #20). Next: 3.3 Lab 15 backup. |
| 2026-06-13 | 3.4 Lab 16 capstone | Built `labs/16-capstone` (branch `lab/eit101-capstone`). The crown integration lab: **one standalone compose, 29 services** — every Lab 01–15 service booting into the cumulative end-state (each lab left config as student work; the capstone pre-bakes it all). **No new images** (dc1=`samba-ad-wazuh`, workstations=`workstation-wazuh`; backup volume-style). Three parts per DESIGN: **A** onboard "Dave" across all systems, **B** three planted cross-layer outages, **C** architecture diagram. **Validated tier-by-tier on the 3.8 GB Mac** (full ~7 GB simultaneous deploy is for the lab machine): foundation (dns1 conditional-forward, kinit, ntp1), fs1 shares+ACLs, mail1 (AD LDAPS, Dovecot auth-bind), **Keycloak SSO** (kcadm-built realm exported+secret-injected to `--import-realm`; alice login, JWT groups=engineering), proxy1 (Kerberos Negotiate + group ACL), radius1 (eapol_test → VLAN 10/20), monitoring (8 targets up, HostDown→hook1), Wazuh (agents auto-enrolled+Active), and **all 3 break/fix scripts** (DNS forwarder; KDC clock via libfaketime → mass "password expired" since krb5's vDSO defeats KRB_AP_ERR_SKEW; mail LDAP bind pw). **Key gotchas:** kcadm user-storage `parentId` must = realm UUID (set `id=lab-corp`); recreate-with-volume resets dc1 smb.conf to standalone (clean down-v/up); dhcp1 dropped (clientless). dhcp1→3.5? PR pending. |
| 2026-06-13 | 3.5 EIT101 reality notes | Doc-only. Added a "Reality Notes: Samba vs Windows AD" section to `enterprise-it-101/README.md`: structural caveats (2008 R2 FFL, GPO stored-but-not-enforced-on-Linux, `samba-tool` ≈ dcpromo + AD PowerShell module) + a **per-lab PowerShell/RSAT equivalence table** (all 16 labs, Samba/Linux → Windows AD tooling). **IPv6 decision: explicit out-of-scope note** (not a Lab 05/06 exercise) — labs are IPv4-only by design (`10.100.0.0/16`); note explains what dual-stack would add (AAAA + ip6.arpa, DHCPv6/SLAAC via kea-dhcp6, v6 listeners) and points at Labs 05/06 as the addressing-plane entry point if pursued. Chose the note over an exercise because 3.5 is scoped doc-only and retrofitting v6 into already-merged/validated labs is out of proportion to the lesson (identity/Kerberos/PKI concepts are addressing-agnostic). **Phase 3 complete.** Next: Phase 4 (4.0 prototype is the load-bearing unknown). PR pending. |
| 2026-06-13 | 4.2 + 4.3 — PHASE 4 COMPLETE | `faults.sh` ships 4 cross-layer faults (F1 routing→Kerberos, F2 RADIUS-secret→802.1X, F3 relay-helper→DHCP, F4 peer-link→VRRP), each validated inject+clear and documented (symptom→hints→cause) in README Part B. Full student-facing README written to the AUTHORING.md structure (Part A observe / Part B troubleshoot / challenge Qs). Docs updated (coverage-map enterprise-design + AAA rows; study-paths cross-track summit). **Phase 4 done → the whole gap-closure plan is complete.** Lab self-contained under `labs/enterprise-grand-capstone/` (own Dockerfile → `gcap-node:local`; reuses EIT101 service images). Not yet committed — on `main`, needs a branch + PR. |
| 2026-06-13 | 4.1 grand capstone — BUILT + VALIDATED | `labs/enterprise-grand-capstone` deploys end-to-end and every integration is verified live from a clean `gcap.sh deploy`. **Topology:** cEOS collapsed core (isp/edge/cc1/cc2) + Linux/hostapd access (access-sw1/2) + endpoints (corp/voip/guest), bonded to the real EIT101 services (dc1/dns1/radius1/dhcp1) over the pinned `br-eitcorp` seam. **Proven:** 802.1X PEAP→radius1→AD (EAP-SUCCESS, port→VLAN10), DHCP-relay→Kea on all 3 VLANs, DDNS PTR into bind9, DNS→AD forward, `kinit bob` TGT, guest segmentation, internet. **cEOS gotchas found the hard way (all worked around in-config):** (1) VRRP syntax is `vrrp N ipv4 <vip>` not `ip`; (2) cEOS virtual dataplane does NOT enforce SVI ACLs → moved segmentation to an egress ACL on the physical seam port; (3) cEOS source-NAT is a no-op that also BREAKS transit on the port → removed NAT, ISP carries a static back to 10.0.0.0/8; (4) collapsed cores need an L2 peer-link trunk (not just the routed interlink) or VRRP dual-masters + return paths go asymmetric; (5) clab linux endpoints must drop the mgmt default (eth0) so DHCP installs the campus default; (6) Kea 2.0.2 rejects `_comment` map keys. Sizing: 4 cEOS @ ~1.5 GiB + services fits 15 GiB. **Remaining: 4.2 planted faults + README, 4.3 doc updates.** |
| 2026-06-13 | 4.1 802.1X→AD integration proof | **PROVED end-to-end** with the real EIT101 images (`samba-ad`, `freeradius-ad`, `nac-lab` all built fresh). Brought up EIT101 Lab 12 (dc1+radius1+nas1); confirmed PEAP/MSCHAPv2 for AD user `bob`/`P@ssw0rd1` → Access-Accept (sanity, from nas1). Then deployed a **clab hostapd authenticator + wpa_supplicant supplicant bridged into lab-corp** (bridge node from 4.0): supplicant PEAP → authenticator (driver=wired) → radius1 (10.100.20.10, secret `testing123`) → `ntlm_auth` → dc1 Samba AD → **EAP-SUCCESS**. So the campus access layer can authenticate against real AD. **Reuse notes for 4.1:** authenticator needs a lab-corp IP + an authorized `client` block in radius1 `clients.conf` (Lab 12 leaves that a student TODO — capstone must ship it filled); supplicant can skip server-cert validation (`eapol_flags=0`, no `ca_cert`). dc1 provisions in ~a few s here (15Gi host); radius1 auto-joins AD via `radius-join.sh`. Cleaned up; reverted the temp clients.conf edit. Next: 4.1 design/scaffold. |
| 2026-06-13 | 4.0 clab↔lab-corp prototype | **PROVED, no fallback needed.** Throwaway test: clab `bridge`-kind node (name == lab-corp Linux bridge) + router veth into it → bidirectional L3 to a lab-corp container; transit routing through the clab router also works both ways. **Key enabler:** pin the bridge name with `com.docker.network.bridge.name=br-labcorp` so the topology can hard-code it (base compose must add this opt). **4.1 gotchas:** clab nodes default-route via clab mgmt (must override campus host default, not append); lab-corp services default-route to the docker host (return path to a campus subnet needs a host route or per-service static, else bridge access natively into 10.100.0.0/16). **`containerlab` is setuid root here — run without `sudo`.** Next: 4.1 build `labs/enterprise-grand-capstone`. |
| 2026-06-13 | 3.3 Lab 15 backup | Built `labs/15-backup-recovery` (branch `lab/eit101-backup`). BorgBackup; two new images: `backup-server` (sshd + borg account, repos under /srv/backups) and `samba-ad-backup` (FROM samba-ad + borg/ssh/cron, cron under supervisord via appended `[include]`). Containers: dc1, ca1 (Lab 03 step-ca, untouched), backup1, admin-ws. **Fully validated on a clean down-v/up walk** (10 tasks): SSH-trust push backups, repokey encryption, dbcheck+offline backup, dedup (~230kB delta for 1 user), CA backed up volume-style via ca1-data mounted into backup1 at /mnt/ca1. **Disaster #1 (AD):** `rm sam.ldb` → kinit *still works* (unlinked open FDs); restart → entrypoint auto-provisions a *fresh* domain (new SID, derek gone) = the trap; `borg extract` restores, SID + derek verified, kinit OK. **Disaster #2 (CA):** delete intermediate_ca_key → in-memory issuance survives until restart → ca1 exits(2); selective `borg extract secrets/intermediate_ca_key` from backup1 → issuance restored. Cron+prune (keep-daily collapses same-day archives — feature, validated), wrong-passphrase rejection, key export. **Gotcha: winbind lags samba-tool after restart** — `wbinfo` readiness gate, not `samba-tool user list`. PR pending. Next: 3.4 Lab 16 capstone (or 3.5 reality notes). |
