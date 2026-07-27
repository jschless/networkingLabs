# Topic Quizzes

Short written assessments for one protocol or tightly related skill area. Use these after
the prerequisite labs and before a broad exam.

Like the exams, quizzes are closed-book paper tests. They use unfamiliar topologies and
evidence so that remembering a lab's solution is not enough. Unlike the exams, they are
formative: the result says what to review next, not whether an entire learning path has
been completed.

## Recommended sequences

These are administration aids, not additional learning paths. Assign only the next quiz
that matches the learner's current labs, or use a short sequence when several related
skills need to be checked.

- **Routing fundamentals:** Routed Network Foundations → Layer 2 → one or more of OSPF,
  EIGRP, and IS-IS → IGP Synthesis → BGP Fundamentals → Route Control & Redistribution.
- **Service provider and data center:** MPLS Forwarding & VPNs → BGP Labeled Unicast →
  SR Linux SR-MPLS Operations → Data-Center EVPN → SR Linux VXLAN-EVPN Operations →
  High Availability.
- **Enterprise campus:** Enterprise Campus Design → Enterprise Access Security → DHCP,
  DNS & Enterprise Services → VRFs & Routed Segmentation → Enterprise QoS → Enterprise
  Wireless Operations → Application Delivery.
- **Secure connectivity:** Management-Plane Security → GRE, IPsec & MTU → WireGuard or
  FlexVPN → DMVPN → Remote Access & Zero Trust → MACsec Link Security.
- **Operations and automation:** Packet Analysis → Network Observability & Assurance →
  Network Automation & Source of Truth → Zero-Touch Provisioning → Troubleshooting
  Methodology.
- **Cloud and modern WAN:** IPv6 & Dual-Stack Operations → SD-WAN & Orchestrated
  Overlays → Hybrid Cloud Networking → Kubernetes Service Networking.
- **Security operations:** Network Detection & PCAP Investigation → Threat Intelligence
  & YARA → SIEM & Incident Response.

## Quiz catalog

| Quiz | Prerequisite labs | Time | Points |
|---|---|---:|---:|
| [OSPF](ospf.md) | OSPF track, including OSPFv3 | 35 min | 30 |
| [EIGRP](eigrp.md) | `eigrp-basics`, `eigrp-variance`, `eigrp-stub` | 25 min | 20 |
| [IS-IS](isis.md) | `isis-basics`, `isis-multiarea` | 25 min | 20 |
| [IGP Synthesis](igp-synthesis.md) | OSPF, EIGRP, and IS-IS quizzes | 50 min | 40 |
| [BGP Fundamentals](bgp-fundamentals.md) | BGP basics, path selection, and MP-BGP | 35 min | 30 |
| [BGP Policy & Security](bgp-policy-security.md) | BGP filtering through RPKI and IXP operations | 40 min | 30 |
| [Layer 2](layer2.md) | VLAN, hardening, STP, and LACP tracks | 25 min | 20 |
| [Route Control & Redistribution](route-control.md) | Redistribution tags, PBR, and IP SLA tracking | 35 min | 30 |
| [MPLS Forwarding & VPNs](mpls.md) | LDP, Segment Routing, and MPLS VPN labs | 40 min | 30 |
| [Data-Center EVPN](evpn.md) | CLOS, VXLAN-EVPN, border leaf, and routed DCI | 40 min | 30 |
| [GRE, IPsec & MTU](tunnel-security.md) | GRE, IPsec, NAT-T, and PMTUD labs | 35 min | 30 |
| [DMVPN](dmvpn.md) | DMVPN Phases 1–3 | 25 min | 20 |
| [High Availability](high-availability.md) | BFD, VRRP, anycast, state sync, and GR | 40 min | 30 |
| [Enterprise Campus Design](enterprise-design.md) | Collapsed core, three-tier, routed access, and WAN edge | 40 min | 30 |
| [Enterprise Access Security](access-security.md) | L2 binding controls, 802.1X, and uRPF | 35 min | 30 |
| [NAT & Stateful Firewalls](nat-firewall.md) | Edge NAT, DMZ policy, state, and NGFW operations | 25 min | 20 |
| [Enterprise QoS](qos.md) | Classification, scheduling, AQM, and policing | 25 min | 20 |
| [Network Observability & Assurance](observability.md) | Polling, telemetry, assertions, flow, logs, and packets | 40 min | 30 |
| [Network Automation & Source of Truth](automation.md) | Structured APIs, idempotence, NetBox, and drift | 40 min | 30 |
| [Application Delivery](application-delivery.md) | Load balancing, service health, GSLB, persistence, and caching | 40 min | 30 |
| [IPv6 & Dual-Stack Operations](ipv6.md) | Access services, OSPFv3, MP-BGP, coexistence, and renumbering | 40 min | 30 |
| [Enterprise Multicast](multicast.md) | IGMP, PIM-SM, RP behavior, RPF, and tree troubleshooting | 25 min | 20 |
| [VRFs & Routed Segmentation](segmentation.md) | VRF-Lite, route leaking, shared services, and black-core separation | 40 min | 30 |
| [Management-Plane Security](management-security.md) | ACLs, AAA, access isolation, and CoPP | 40 min | 30 |
| [Enterprise Wireless Operations](wireless.md) | WLAN architecture, EAP-TLS, role projection, and evidence boundaries | 40 min | 30 |
| [SD-WAN & Orchestrated Overlays](sdwan.md) | Overlay planes, controller state, segmentation, and SLA steering | 40 min | 30 |
| [Hybrid Cloud Networking](hybrid-cloud.md) | Attachments, route association, inspection, DNS, and overlap | 40 min | 30 |
| [Kubernetes Service Networking](kubernetes-networking.md) | MetalLB, BGP, ECMP, endpoints, and external traffic policy | 40 min | 30 |
| [Remote Access & Zero Trust](remote-access.md) | Tunnel identity, split routing, resource policy, and revocation | 40 min | 30 |
| [MACsec Link Security](macsec.md) | Link encryption, MKA, capture boundaries, and key lifecycle | 25 min | 20 |
| [DHCP, DNS & Enterprise Services](enterprise-services.md) | Relay, lease options, name service, NTP, and syslog | 40 min | 30 |
| [Zero-Touch Provisioning](ztp.md) | Bootstrap state, option 67, trust, fleet rollout, and rescue | 40 min | 30 |
| [Packet Analysis](packet-analysis.md) | Capture placement, protocol evidence, one-way faults, and TLS limits | 25 min | 20 |
| [Carrier Ethernet Handoffs](carrier-ethernet.md) | QinQ, MTU, PCP, acceptance, and demarc escalation | 40 min | 30 |
| [Network Detection & PCAP Investigation](network-detection.md) | Zeek, Suricata, Arkime, triage, and retention | 40 min | 30 |
| [Threat Intelligence & YARA](threat-intel-yara.md) | IOC lifecycle, file rules, scoring, and tuning | 40 min | 30 |
| [SIEM & Incident Response](siem-ir.md) | Normalization, dashboards, timelines, cases, and detection coverage | 40 min | 30 |
| [WireGuard](wireguard.md) | Key identity, `AllowedIPs`, topology, and rotation | 25 min | 20 |
| [FlexVPN & Route-Based IPsec](flexvpn.md) | IKEv2, VTI/XFRM binding, routing, and hub scaling | 25 min | 20 |
| [BGP Labeled Unicast](bgp-lu.md) | Labeled AF, ASBR stitching, LFIB, and Inter-AS Option C | 40 min | 30 |
| [SR Linux SR-MPLS Operations](srlinux-mpls.md) | Network instances, SR labels, VPNv4, and modeled operations | 25 min | 20 |
| [SR Linux VXLAN-EVPN Operations](srlinux-evpn.md) | MAC-VRF, IMET/MAC routes, VNI, and native operations | 25 min | 20 |
| [Routed Network Foundations](routing-foundations.md) | Lab lifecycle, adjacency state, timers, routes, and verification | 25 min | 20 |
| [Troubleshooting Methodology](troubleshooting-method.md) | Scope, evidence, minimal repair, verification, and PMTUD | 40 min | 30 |

Most quizzes test depth in one protocol or operational topic. IGP Synthesis is
deliberately different: it tests comparison, protocol selection, and safe redistribution
after the individual protocols are understood.

## Formats

**Standard topic quiz — 30 points, 30–40 minutes**

| Section | Points | Measures |
|---|---:|---|
| Mechanisms | 6 | Why the protocol behaves as it does |
| Evidence reading | 8 | Diagnosis from supplied output |
| Application | 10 | Configuration or protocol-state reasoning |
| Design and troubleshooting | 6 | Operational method and trade-offs |

Compact quizzes for smaller tracks use 20 points in about 25 minutes. Synthesis quizzes
may use 40 points and up to 50 minutes, but remain narrower than a full exam.

## Reading a result

For a 30-point quiz:

| Score | Reading |
|---:|---|
| 24–30 | Ready to continue |
| 21–23 | Review the mapped weak areas |
| 0–20 | Re-run the core topic labs before retaking |

For other totals, use the same thresholds: 80% is ready, 70–79% calls for targeted
review, and below 70% calls for a fuller lab repeat.

Keys are in [`../answer-keys/quizzes/`](../answer-keys/quizzes/README.md). Do not open a
key before taking its quiz.

## Authoring contract

Every quiz must:

- map every question to an existing lab and learning objective;
- include new questions rather than copies of questions from a broad exam;
- include at least one changed-topology transfer problem;
- require evidence interpretation and application, not only recall;
- provide point-by-point marking, misconception notes, and remediation;
- state its prerequisites, time, total, and allowed resources.
