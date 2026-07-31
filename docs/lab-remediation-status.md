# Lab Remediation Status

This ledger is the durable orchestration record for the networking-lab curriculum
remediation. It was initialized from the filesystem rather than from a hand-maintained
catalog.

- Branch: `codex/networking-lab-remediation`
- Base: `origin/main` at `d812c39d2448c44a0566f12250b0aff9c299f6a5`
- Inventory date: 2026-07-31
- Topology-backed labs: 143
- Processing policy: exactly one lab is analyzed, edited, deployed, reviewed, committed,
  and cleaned up at a time.
- Global validation limitation: the requested installed `lab-tutor` skill is not
  available in this Codex session. Student-flow review therefore uses
  `labs/AUTHORING.md` as the fallback contract. No ledger entry may claim
  `lab-tutor` validation unless that skill later becomes available and is actually run.

## Status meanings

- `pending`: inventoried but not yet completed.
- `compliant`: inspected and no remediation was required.
- `changed`: remediated and committed.
- `blocked-external`: safe static work is complete, but an external dependency prevented
  required live validation.
- `intentionally-exempt`: excluded from the active workflow for a documented reason.

## Per-lab ledger

| Lab | Status | Lab type | Instructional findings | Platform decision | FRR/Linux exception | Validation performed | Peak memory | Commit SHA | Remaining limitation |
|---|---|---|---|---|---|---|---|---|---|
| aaa-ops-troubleshooting | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| acl-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| advanced-security-architecture | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| anycast-dns | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| automation-fundamentals | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bfd-bgp | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bfd-ospf | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bgp-aggregation | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bgp-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bgp-communities | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bgp-filtering | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bgp-labeled-unicast | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bgp-path-selection | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bgp-prefix-security | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| bgp-rpki | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| black-core-routing | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| campus-l2-hardening | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| carrier-ethernet-handoff | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| cloud-hybrid-networking | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| copp-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dc-storage-networking | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dci-evpn-multisite | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-bgp-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-bgp-filtering | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-bgp-path-selection | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-dmvpn-phase1 | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-eigrp-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-gre-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-isis-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-mpls-sr-isis-bgp | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-ospf-auth | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-ospf-bgp-redist | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-ospf-multiarea | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-ospf-nssa | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-spine-leaf | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-vrf-lite | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| debug-vxlan-evpn | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dhcp-dns-troubleshooting | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dmvpn-ceos | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dmvpn-phase1 | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dmvpn-phase2 | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dmvpn-phase3 | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dmvpn-phase3-ipsec-capstone | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dot1x-ceos-practice | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| dot1x-nac | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| eigrp-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| eigrp-stub | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| eigrp-variance | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-access-security | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-campus | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-campus-capstone | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-collapsed-core | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-collapsed-core-capstone | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-dmz | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-dmz-capstone | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-dual-stack-capstone | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-edge-nat-firewall | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-grand-capstone | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-multicast | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-routed-access | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-routed-access-capstone | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-services-infra | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-voice-sip-qos | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-wan-edge | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-wan-edge-capstone | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| enterprise-wireless-architecture | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| evpn-border-ceos | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| flexvpn-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| global-application-delivery | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| graceful-restart | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| gre-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| gre-ipsec | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ha-network-design-ceos | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| internet-peering-ixp | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ip-sla-tracking | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ipsec-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ipv6-access-services | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ipv6-bgp | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ipv6-ospf3 | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ipv6-transition | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| isis-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| isis-multiarea | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| k8s-fabric | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| lacp-etherchannel | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| load-balancer-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| macsec-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| management-access-control | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| mpls-l2vpn | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| mpls-ldp | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| mpls-sr-blank | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| mpls-sr-isis-bgp | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| mpls-sr-srlinux | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| mtu-pmtud-troubleshooting | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| network-assurance | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| network-automation-netbox | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| network-gitops-change-pipeline | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| opnsense-ipsec-nat-t | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| opnsense-ngfw-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| opnsense-remote-access-concentrator | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| orchestrated-wan-overlay | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ospf-auth | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ospf-bgp-redist | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ospf-default-route | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ospf-multiarea | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ospf-nssa | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ospf-summarization | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ospf-virtual-link | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ot-zone-conduit | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| packet-analysis-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| qos-enterprise | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| redistribution-tags | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| route-maps-pbr | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| sdwan-concepts | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| service-ha | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-adversary-simulation | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-arkime-pcap | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-dmz-foundation | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-elk-ingest | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-ir-case-management | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-kibana-hvt-dashboard | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-suricata-ids | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-threat-intel-misp | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-yara-file-pipeline | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| soc-zeek-analysis | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| spine-leaf | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| stp-operations | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| suzieq-network-observability | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| troubleshooting-range | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| troubleshooting-range-advanced | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| troubleshooting-range-campus | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| troubleshooting-range-dci-edge | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| troubleshooting-range-hybrid-access | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| two-routers | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| urpf-antispoofing | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| vlan-trunks-switchport-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| vrf-lite | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| vrrp | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| vxlan-evpn | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| vxlan-evpn-srlinux | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| wireguard | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| wireless-auth-control-operations | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| zero-trust-secure-access | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
| ztp-basics | pending | Unclassified | Analyst pass pending | Pending | Pending | Not run | Not recorded | Pending | Lab-specific validation pending |
