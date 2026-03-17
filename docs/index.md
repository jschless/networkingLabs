# ContainerLab Networking Labs

**103 hands-on networking labs** running locally with [ContainerLab](https://containerlab.dev/), [FRRouting](https://frrouting.org/), [Arista cEOS](https://www.arista.com/en/support/software-download), [VyOS](https://vyos.io/), and [Nokia SR-Linux](https://learn.srlinux.dev/).

No cloud account. No license fees. Deploy, break things, learn.

---

## Quick Start

=== "FRR Lab"
    ```bash
    # Build the FRR image (required once)
    docker build -t frr-lab:local images/frr/

    # Deploy a lab
    sudo containerlab deploy -t labs/ospf-multiarea/topology.clab.yml

    # Open FRR CLI
    docker exec -it clab-ospf-multiarea-r1 vtysh

    # Destroy when done
    sudo containerlab destroy -t labs/ospf-multiarea/topology.clab.yml --cleanup
    ```

=== "Arista cEOS Lab"
    ```bash
    # Import cEOS image (one-time)
    docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F

    # Deploy
    sudo containerlab deploy -t labs/spine-leaf-ceos/topology.clab.yml

    # Open EOS CLI
    docker exec -it clab-spine-leaf-ceos-spine1 Cli

    # Destroy
    sudo containerlab destroy -t labs/spine-leaf-ceos/topology.clab.yml --cleanup
    ```

=== "VyOS Lab"
    ```bash
    # Build the VyOS router image (one-time)
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

## Lab Tracks

<div class="grid cards" markdown>

- :material-router-network: **OSPF** (9 labs)

    ---
    Single-area through multi-area, auth, summarization, redistribution, OSPFv3

    [:octicons-arrow-right-24: OSPF track](tracks/ospf/index.md)

- :material-infinity: **EIGRP** (3 labs)

    ---
    DUAL convergence, variance, stub routers

    [:octicons-arrow-right-24: EIGRP track](tracks/eigrp/index.md)

- :material-transit-connection-variant: **BGP** (9 labs)

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
    GRE, IPsec, DMVPN Phase 1/2/3, FlexVPN, WireGuard, VRF-Lite

    [:octicons-arrow-right-24: Tunnels & VPN track](tracks/tunnels-vpn/index.md)

- :material-cloud-tags: **MPLS & SP** (5 labs)

    ---
    IS-IS + SR-MPLS + BGP VPNv4, L2VPN, 6PE

    [:octicons-arrow-right-24: MPLS & SP track](tracks/mpls-sp/index.md)

- :material-server-network: **Data Center** (6 labs)

    ---
    BGP CLOS, VXLAN, BGP EVPN, border leaf, symmetric IRB

    [:octicons-arrow-right-24: Data Center track](tracks/data-center/index.md)

- :material-high-definition: **High Availability** (5 labs)

    ---
    BFD, VRRP, Graceful Restart, MLAG, multi-mechanism HA design

    [:octicons-arrow-right-24: HA track](tracks/high-availability/index.md)

- :material-office-building: **Enterprise Design** (14 labs)

    ---
    Campus tiers, WAN edge, access security, multicast, services, capstones

    [:octicons-arrow-right-24: Enterprise track](tracks/enterprise/index.md)

- :material-switch: **Layer 2** (4 labs)

    ---
    VLANs and trunks, L2 hardening, STP operations, LACP EtherChannel

    [:octicons-arrow-right-24: Layer 2 track](tracks/layer2/index.md)

- :material-shield-lock: **Security** (6 labs)

    ---
    ACLs, MACsec, 802.1X/NAC, uRPF, CoPP, dot1x on EOS

    [:octicons-arrow-right-24: Security track](tracks/security/index.md)

- :material-chart-line: **Network Operations** (10 labs)

    ---
    Management access, DHCP/DNS, AAA, packet capture, MTU troubleshooting, SNMP/syslog/NetFlow, QoS, NetBox automation, gNMI telemetry

    [:octicons-arrow-right-24: Operations track](tracks/operations/index.md)

- :material-bug: **Debug Labs** (15 labs)

    ---
    One real bug per lab — scenario, symptoms, 3-level hints, solution

    [:octicons-arrow-right-24: Debug track](tracks/debug/index.md)

</div>
