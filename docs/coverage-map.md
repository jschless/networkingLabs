# CCNP Exam Coverage Map

This page maps every topic on the two CCNP Enterprise exam blueprints to the labs in
this repo, honestly. It is the acceptance test for what this repo does and does not
teach — when a new lab lands, update the matching rows.

**Blueprints used** (fetched from Cisco, June 2026):

- **ENCOR 350-401 v1.2** (© 2025 Cisco) — the current core exam. Note: v1.2 **removed
  the wireless domain entirely** and folded automation into a combined
  "Automation and Artificial Intelligence" domain. Earlier study guides written for
  v1.0/v1.1 still cover wireless RF; the live exam no longer tests it.
- **ENARSI 300-410 v1.1** (© 2023 Cisco) — the advanced routing concentration exam.

**Statuses:**

| Status | Meaning |
|--------|---------|
| ✅ Covered | A lab exercises this hands-on, and the skill transfers directly. |
| 🟡 Conceptual | A lab teaches the concept and behavior, but on FRR/cEOS/VyOS/Linux — IOS-XE syntax differs, so pair it with syntax drill. See [Platform fidelity](study-paths.md#platform-fidelity-what-these-labs-do-and-dont-teach). |
| ❌ Not covered | No lab. Study from notes/reading; flagged in the [gap summary](#gap-summary) if a lab is planned. |

Read this page together with the [study paths](study-paths.md), which sequence these
labs into an order.

---

## ENCOR 350-401 v1.2

### 1.0 Architecture (15%)

| Topic | Status | Labs |
|-------|--------|------|
| 1.1.a Enterprise design: 2-tier, 3-tier, fabric, cloud | ✅ | `enterprise-collapsed-core` (2-tier), `enterprise-campus` (3-tier), `enterprise-routed-access` (L3 access), `spine-leaf` (fabric) + their capstones |
| 1.1.b HA techniques: redundancy, FHRP, SSO | 🟡 | `vrrp`, `ha-network-design-ceos`, `graceful-restart`, `bfd-ospf`, `bfd-bgp` — VRRP hands-on; HSRP/GLBP and SSO are Cisco-only (theory) |
| 1.2 Catalyst SD-WAN principles | ❌ | Planned: `sdwan-concepts` (PLAN.md Phase 2.3) |
| 1.3 SD-Access principles | ❌ | Underlying data plane (VXLAN) is covered below; LISP control plane and DNA/Catalyst Center are not |
| 1.4 Interpret QoS configurations | 🟡 | `qos-enterprise` — classification/scheduling with Linux `tc`, not MQC syntax |

### 2.0 Virtualization (10%)

| Topic | Status | Labs |
|-------|--------|------|
| 2.1 Device virtualization (hypervisors, VMs, vSwitch) | ❌ | Theory only — though running these container labs *is* applied device virtualization |
| 2.2.a VRF | ✅ | `vrf-lite`, `debug-vrf-lite` |
| 2.2.b GRE and IPsec tunneling | ✅ | `gre-basics`, `gre-ceos`, `ipsec-basics`, `gre-ipsec` |
| 2.3.a LISP | ❌ | No FRR/cEOS-container support; study notes |
| 2.3.b VXLAN | ✅ | `vxlan-evpn`, `evpn-vxlan-ceos`, `evpn-border-ceos`, `vxlan-evpn-srlinux`, `debug-vxlan-evpn` |

### 3.0 Infrastructure (30%)

| Topic | Status | Labs |
|-------|--------|------|
| 3.1.a 802.1q trunking (static and dynamic) | 🟡 | `vlan-trunks-switchport-basics`, `campus-l2-hardening` — static trunking hands-on on cEOS; DTP is Cisco-only |
| 3.1.b EtherChannels (static and dynamic) | 🟡 | `lacp-etherchannel` — static + LACP on cEOS; PAgP is Cisco-only |
| 3.1.c STP (RSTP, MST), root guard, BPDU guard | ✅ | `stp-operations`, `campus-l2-hardening` |
| 3.2.a EIGRP vs OSPF routing concepts | ✅ | `eigrp-basics`, `eigrp-variance`, `eigrp-stub` vs the OSPF track |
| 3.2.b OSPFv2/v3: multiarea, summarization, filtering, network types | ✅ | `ospf-multiarea`, `ospf-summarization`, `ospf-default-route`, `ospf-auth`, `ipv6-ospf3` |
| 3.2.c eBGP between directly connected neighbors | ✅ | `bgp-basics`, `bgp-path-selection` |
| 3.2.d Policy-based routing | ✅ | `route-maps-pbr` |
| 3.3.a NTP and PTP | 🟡 | `enterprise-services-infra` (NTP), `enterprise-it-101/02-ntp-time-services` — PTP not covered |
| 3.3.b NAT/PAT | 🟡 | `enterprise-edge-nat-firewall`, `enterprise-dmz` (+capstone), `fortigate-firewall-capstone` — nftables/FortiGate, not IOS `ip nat` syntax |
| 3.3.c FHRP (HSRP, VRRP) | 🟡 | `vrrp`, `ha-network-design-ceos` — VRRP hands-on; HSRP syntax is Cisco-only |
| 3.3.d Multicast (RPF, PIM-SM, IGMP, SSM) | ✅ | `enterprise-multicast` |

### 4.0 Network Assurance (10%)

| Topic | Status | Labs |
|-------|--------|------|
| 4.1 Diagnose with debugs, traceroute, ping, SNMP, syslog | ✅ | `network-assurance`, `telemetry-monitoring-hybrid`, the entire `debug-*` track |
| 4.2 Flexible NetFlow | 🟡 | `telemetry-monitoring-hybrid` — flow export concepts, not IOS FNF record/monitor syntax |
| 4.3 SPAN/RSPAN/ERSPAN | 🟡 | `packet-analysis-basics`, `soc-dmz-foundation` (mirror feed) — port mirroring concepts, not Catalyst SPAN syntax |
| 4.4 IP SLA | 🟡 | `ip-sla-tracking` — probe + tracked-object failover behavior; syntax differs |
| 4.5 Cisco Catalyst Center (DNA Center) workflows | ❌ | Product-specific; study notes / sandbox |
| 4.6 NETCONF and RESTCONF | ❌ | `telemetry-monitoring-hybrid` touches gNMI; NETCONF/RESTCONF planned in `automation-fundamentals` (PLAN.md Phase 2.1) |

### 5.0 Security (20%)

| Topic | Status | Labs |
|-------|--------|------|
| 5.1 Device access control (lines, local users, AAA) | ✅ | `management-access-control`, `aaa-ops-troubleshooting` (TACACS+ and RADIUS), `dot1x-ceos-practice` |
| 5.2.a ACLs | ✅ | `acl-basics` |
| 5.2.b CoPP | ✅ | `copp-basics` |
| 5.3 REST API security | ❌ | Planned alongside `automation-fundamentals` (PLAN.md Phase 2.1) |
| 5.4.a–c Threat defense, endpoint security, NGFW | 🟡 | `fortigate-firewall-capstone`, `enterprise-edge-nat-firewall`, the SOC track (`soc-*`) — deeper than the exam needs, but not Cisco Firepower/ISE |
| 5.4.d TrustSec and MACsec | 🟡 | `macsec-basics` hands-on; TrustSec/SGT is Cisco-only (theory) |

### 6.0 Automation and Artificial Intelligence (15%)

| Topic | Status | Labs |
|-------|--------|------|
| 6.1 Interpret basic Python | ❌ | Planned: `automation-fundamentals` (PLAN.md Phase 2.1) |
| 6.2 Construct valid JSON | 🟡 | JSON appears throughout (`soc-*` EVE/Zeek logs, gNMI output); no dedicated exercise |
| 6.3 Data modeling languages (YANG) | 🟡 | `telemetry-monitoring-hybrid` (gNMI paths are YANG-derived); no YANG-reading exercise |
| 6.4 APIs for Catalyst Center and SD-WAN Manager | ❌ | Product-specific; study notes |
| 6.5 Interpret REST API response codes/payloads | ❌ | Planned: `automation-fundamentals` (PLAN.md Phase 2.1) |
| 6.6 EEM applets | ❌ | IOS-only feature; study notes |
| 6.7 Agent vs agentless orchestration | 🟡 | `network-automation-netbox` (source of truth + automation), `enterprise-it-101` Lab 09 area uses Ansible — comparison itself is theory |

---

## ENARSI 300-410 v1.1

### 1.0 Layer 3 Technologies (35%)

| Topic | Status | Labs |
|-------|--------|------|
| 1.1 Administrative distance | ✅ | `ospf-bgp-redist`, `redistribution-tags`, `debug-ospf-bgp-redist` |
| 1.2 Route maps (attributes, tagging, filtering) | ✅ | `route-maps-pbr`, `bgp-filtering`, `redistribution-tags` |
| 1.3 Loop prevention (filtering, tagging, split horizon, poisoning) | ✅ | `redistribution-tags` (tag-based loop prevention), `eigrp-stub` |
| 1.4 Redistribution between protocols | ✅ | `ospf-bgp-redist`, `redistribution-tags`, `debug-ospf-bgp-redist` |
| 1.5 Manual and auto-summarization | ✅ | `ospf-summarization`, `bgp-aggregation` |
| 1.6 Policy-based routing | ✅ | `route-maps-pbr` |
| 1.7 VRF-Lite | ✅ | `vrf-lite`, `debug-vrf-lite` |
| 1.8 BFD | ✅ | `bfd-ospf`, `bfd-bgp` |
| 1.9 EIGRP (classic and named; VRF and global) | 🟡 | `eigrp-basics`, `eigrp-variance`, `eigrp-stub`, `debug-eigrp-basics` — FRR EIGRP is classic-mode IPv4 only; **named mode, EIGRP IPv6, and EIGRP auth must be drilled on Cisco images** |
| 1.10 OSPF v2/v3 (network/area/router types, virtual link, path preference) | ✅ | `ospf-multiarea`, `ospf-nssa`, `ospf-virtual-link`, `ospf-auth`, `ospf-default-route`, `ipv6-ospf3`, `debug-ospf-*` |
| 1.11 BGP (iBGP/eBGP, path preference, RR, policies) | ✅ | `bgp-basics`, `bgp-path-selection`, `bgp-filtering`, `bgp-communities`, `bgp-aggregation`, `graceful-restart` (route reflector), `ipv6-bgp`, `debug-bgp-*` |

### 2.0 VPN Technologies (20%)

| Topic | Status | Labs |
|-------|--------|------|
| 2.1 MPLS operations (LSR, LDP, label switching, LSP) | 🟡 | `mpls-sr-blank`, `mpls-sr-isis-bgp`, `mpls-sr-srlinux` — label switching hands-on via **Segment Routing, not LDP**; LDP specifics are theory |
| 2.2 MPLS Layer 3 VPN | ✅ | `mpls-sr-isis-bgp` (BGP VPNv4), `bgp-labeled-unicast`, `mpls-l2vpn` (beyond blueprint) |
| 2.3 DMVPN single hub (mGRE, NHRP, IPsec, spoke-to-spoke) | 🟡 | `dmvpn-phase1`, `dmvpn-phase2`, `dmvpn-phase3`, `dmvpn-phase3-ipsec-capstone`, `debug-dmvpn-phase1` — full NHRP/mGRE/IPsec behavior on VyOS; Cisco `ip nhrp` syntax differs |

### 3.0 Infrastructure Security (20%)

| Topic | Status | Labs |
|-------|--------|------|
| 3.1 Device security with AAA (TACACS+, RADIUS, local) | ✅ | `aaa-ops-troubleshooting`, `management-access-control`, `dot1x-nac`, `dot1x-ceos-practice` |
| 3.2.a IPv4 ACLs (standard, extended, time-based) | ✅ | `acl-basics` (time-based: theory) |
| 3.2.b IPv6 traffic filter | 🟡 | `ipv6-access-services` touches host-side filtering; no dedicated IPv6-ACL exercise |
| 3.2.c uRPF | ✅ | `urpf-antispoofing` |
| 3.3 CoPP | ✅ | `copp-basics` |
| 3.4 IPv6 first-hop security (RA guard, DHCP guard, ND inspection) | 🟡 | `ipv6-access-services` (RA guard, SLAAC/DHCPv6 behavior); binding table/ND inspection are switch features not exercised |

### 4.0 Infrastructure Services (25%)

| Topic | Status | Labs |
|-------|--------|------|
| 4.1 Device management (console/VTY, SSH/SCP, (T)FTP) | ✅ | `management-access-control` |
| 4.2 SNMP (v2c, v3) | ✅ | `network-assurance`, `telemetry-monitoring-hybrid` |
| 4.3 Logging (syslog, debugs, conditional debugs) | ✅ | `network-assurance`, `telemetry-monitoring-hybrid`, the `debug-*` track |
| 4.4 IPv4/IPv6 DHCP (client, server, relay, options) | ✅ | `dhcp-dns-troubleshooting`, `ipv6-access-services`, `enterprise-it-101/06-dhcp-dynamic-dns` |
| 4.5 IP SLA (jitter, tracking, delay, connectivity) | 🟡 | `ip-sla-tracking` — probe/track/failover behavior; IOS `ip sla` syntax differs |
| 4.6 NetFlow (v5, v9, flexible) | 🟡 | `telemetry-monitoring-hybrid` — flow concepts, not IOS NetFlow CLI |
| 4.7 Cisco DNA Center assurance | ❌ | Product-specific; study notes / sandbox |

---

## Gap summary

What the matrix says, condensed. ❌ rows cluster into four buckets:

1. **Cisco-proprietary platforms** (Catalyst Center, SD-WAN Manager, EEM, LISP/SD-Access
   control plane, TrustSec): cannot be containerized here. Close these with reading +
   a CML/DevNet-sandbox/Boson pass — see
   [Platform fidelity](study-paths.md#platform-fidelity-what-these-labs-do-and-dont-teach).
2. **Automation hands-on** (ENCOR 6.1, 6.5, 4.6, 5.3): planned as
   `labs/automation-fundamentals` — PLAN.md Phase 2.1.
3. **SD-WAN concepts** (ENCOR 1.2): planned as `labs/sdwan-concepts` — PLAN.md Phase 2.3.
4. **Pure theory** (hypervisor types, PTP, agent-vs-agentless comparison): small enough
   to study from notes; no lab planned.

🟡 rows are real skills learned on non-Cisco syntax. The behavior, troubleshooting
method, and protocol mechanics transfer; the CLI does not. Budget syntax-drill time
proportional to the 🟡 density in each domain (highest: ENCOR 3.3 IP Services and
6.0 Automation).

**Wireless:** absent from this repo *and* from the current ENCOR v1.2 blueprint. The
`enterprise-wireless-architecture` lab covers design/architecture thinking; RF theory
is no longer an exam gap, just a knowledge gap — a curated RF reading list for that
lab's README is planned (PLAN.md Phase 2.3).
