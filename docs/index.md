# Self-Hosted Labs

Hands-on labs across **three tracks**, all running locally on your own machine:

- **Networking** — routing, switching, data center, tunnels/VPN, and enterprise design on
  [ContainerLab](https://containerlab.dev/) with [FRRouting](https://frrouting.org/),
  [Arista cEOS](https://www.arista.com/en/support/software-download),
  [VyOS](https://vyos.io/), [Nokia SR-Linux](https://learn.srlinux.dev/), and
  [OPNsense](https://opnsense.org/).
- **Security Operations (SOC)** — DMZ visibility, Zeek, Suricata, YARA, SIEM ingest,
  dashboards, threat intel, and incident response (also ContainerLab).
- **Enterprise IT 101** — build a complete mini enterprise domain from scratch (AD, PKI, DNS,
  DHCP, email, SSO, RADIUS) using **Docker Compose**.

No cloud account. No license fees. Deploy, break things, learn.

---

## Quick Start

=== "FRR Lab"
    ```bash
    # Build the FRR image (required once)
    docker build -t frr-lab:local images/frr/

    # Deploy a lab
    sudo containerlab deploy -t labs/eigrp-basics/topology.clab.yml

    # Open FRR CLI
    docker exec -it clab-eigrp-basics-r1 vtysh

    # Destroy when done
    sudo containerlab destroy -t labs/eigrp-basics/topology.clab.yml --cleanup
    ```

=== "Arista cEOS Lab"
    ```bash
    # Import cEOS image (one-time)
    docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F

    # Deploy
    sudo containerlab deploy -t labs/spine-leaf/topology.clab.yml

    # Open EOS CLI
    docker exec -it clab-spine-leaf-spine1 Cli

    # Destroy
    sudo containerlab destroy -t labs/spine-leaf/topology.clab.yml --cleanup
    ```

=== "VyOS Lab"
    ```bash
    # Build the VyOS router image (one-time; extract rootfs.tar from a free
    # VyOS ISO first — see Platforms → VyOS)
    docker build -t vyos:local -f Dockerfile.vyos .

    # Deploy
    sudo containerlab deploy -t labs/dmvpn-phase1/topology.clab.yml

    # Open VyOS CLI
    docker exec -it clab-dmvpn-phase1-hub su - admin

    # Destroy
    sudo containerlab destroy -t labs/dmvpn-phase1/topology.clab.yml --cleanup
    ```

=== "Nokia SR-Linux Lab"
    ```bash
    # Pull SR-Linux image (one-time)
    docker pull ghcr.io/nokia/srlinux:latest

    # Deploy
    sudo containerlab deploy -t labs/mpls-sr-srlinux/topology.clab.yml

    # Open SR-Linux CLI
    docker exec -it clab-mpls-sr-srlinux-pe1 sr_cli

    # Destroy
    sudo containerlab destroy -t labs/mpls-sr-srlinux/topology.clab.yml --cleanup
    ```

---

## Networking Labs

<div class="grid cards" markdown>

- :material-router-network: **OSPF** (9 labs)

    ---
    Single-area through multi-area, auth, summarization, redistribution, OSPFv3

    [:octicons-arrow-right-24: OSPF track](tracks/ospf/index.md)

- :material-infinity: **EIGRP** (3 labs)

    ---
    DUAL convergence, variance, stub routers

    [:octicons-arrow-right-24: EIGRP track](tracks/eigrp/index.md)

- :material-transit-connection-variant: **BGP** (10 labs)

    ---
    Sessions, path selection, filtering, communities, RPKI, BGP-LU, IPv6

    [:octicons-arrow-right-24: BGP track](tracks/bgp/index.md)

- :material-graph: **IS-IS** (2 labs)

    ---
    NET address, Level-1/2, multi-area, route leaking

    [:octicons-arrow-right-24: IS-IS track](tracks/isis/index.md)

- :material-map-marker-path: **Route Control** (3 labs)

    ---
    Redistribution tags, policy-based routing, IP SLA

    [:octicons-arrow-right-24: Route Control track](tracks/route-control/index.md)

- :material-tunnel: **Tunnels & VPN** (12 labs)

    ---
    GRE, IPsec, NAT-T, DMVPN Phase 1/2/3, FlexVPN, WireGuard, VPN concentration, VRF-Lite

    [:octicons-arrow-right-24: Tunnels & VPN track](tracks/tunnels-vpn/index.md)

- :material-cloud-tags: **MPLS & SP** (8 labs)

    ---
    LDP, IS-IS + SR-MPLS + BGP VPNv4, L2VPN, 6PE

    [:octicons-arrow-right-24: MPLS & SP track](tracks/mpls-sp/index.md)

- :material-server-network: **Data Center** (6 labs)

    ---
    BGP CLOS, VXLAN, BGP EVPN, border leaf, routed DCI, symmetric IRB, k8s LoadBalancer/BGP

    [:octicons-arrow-right-24: Data Center track](tracks/data-center/index.md)

- :material-high-definition: **High Availability** (7 labs)

    ---
    BFD, VRRP, anycast services, stateful firewall HA, Graceful Restart, MLAG, multi-mechanism HA design

    [:octicons-arrow-right-24: HA track](tracks/high-availability/index.md)

- :material-office-building: **Enterprise Design** (23 labs)

    ---
    Campus tiers, WAN edge, cloud hybrid routing, SD-WAN concepts, load balancing, access security, multicast, services, capstones

    [:octicons-arrow-right-24: Enterprise track](tracks/enterprise/index.md)

- :material-switch: **Layer 2** (4 labs)

    ---
    VLANs and trunks, L2 hardening, STP operations, LACP EtherChannel

    [:octicons-arrow-right-24: Layer 2 track](tracks/layer2/index.md)

- :material-shield-lock: **Security** (9 labs)

    ---
    ACLs, zero-trust access, black-core routing, OPNsense NGFW policy and IPS, MACsec, 802.1X/NAC, uRPF, CoPP, dot1x on EOS

    [:octicons-arrow-right-24: Security track](tracks/security/index.md)

- :material-chart-line: **Network Operations** (16 labs)

    ---
    Management access, DHCP/DNS, AAA, hybrid-flow evidence, packet capture, MTU troubleshooting, SNMP/syslog/NetFlow, QoS, zero-touch provisioning, API automation, NetBox, gNMI telemetry, and SuzieQ observability

    [:octicons-arrow-right-24: Operations track](tracks/operations/index.md)

</div>

---

## Troubleshooting & Assessment

<div class="grid cards" markdown>

- :material-stethoscope: **Troubleshooting & Assessment** (3 ranges, 36 tickets)

    ---
    Progress from 15 guided debug labs with hints and solutions to blind,
    proctored enterprise and edge-routing assessment ranges.

    [:octicons-arrow-right-24: Troubleshooting track](tracks/troubleshooting/index.md)

</div>

---

## Security Operations (SOC)

A separate domain — security tooling rather than routing, but the same ContainerLab workflow.

<div class="grid cards" markdown>

- :material-shield-search: **Security Operations (SOC)** (10 labs)

    ---
    DMZ visibility, Zeek, Suricata, YARA, SIEM ingest, dashboards, packet search, threat intel, IR workflow

    [:octicons-arrow-right-24: Security Operations track](tracks/security-infrastructure/index.md)

</div>

---

## Enterprise IT 101

<div class="grid cards" markdown>

- :material-domain: **Enterprise IT 101** (16 labs)

    ---
    Build a complete mini enterprise domain from scratch: AD, PKI, DNS, DHCP, email, SSO, web proxy, RADIUS, monitoring, SIEM, backups, and a full-stack capstone — using only open-source containers.

    Uses **Docker Compose** (not ContainerLab). Each lab builds on the last.

    [:octicons-arrow-right-24: Enterprise IT 101](tracks/enterprise-it-101/index.md)

</div>
