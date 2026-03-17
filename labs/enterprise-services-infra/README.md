# Enterprise Services Infrastructure Lab

This lab teaches the supporting services that make an enterprise network operational:

- DHCP relay
- DNS and central services placement
- NTP
- TACACS+ for device admin AAA
- centralized syslog
- SNMPv3 and management-plane habits

## Build

```bash
docker build -t enterprise-services-infra:local labs/enterprise-services-infra/
docker build -f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/
sudo containerlab deploy -t labs/enterprise-services-infra/topology.clab.yml
```

## Topology

```mermaid
flowchart TB
    edge1["edge1\nupstream router"]
    campus1["campus1\ncEOS\nVLAN10 + VLAN99"]
    client1(["client1\nDHCP client\nVLAN10"])
    services1(["services1\nDHCP/DNS/NTP/syslog\n192.168.99.10\nVLAN99"])
    mgmt1(["mgmt1\nadmin WS\n192.168.99.30\nVLAN99"])
    tacacs1(["tacacs1\nTACACS+\n192.168.99.20\nVLAN99"])

    edge1 --- campus1
    campus1 --- client1
    campus1 --- services1
    campus1 --- mgmt1
    campus1 --- tacacs1

    classDef router fill:#1a1aff,color:#fff,stroke:#000
    classDef host   fill:#3d7a3d,color:#fff,stroke:#000

    class edge1,campus1 router
    class client1,services1,mgmt1,tacacs1 host
```

- `campus1`: access/distribution switch with user VLAN 10 and management VLAN 99
- `edge1`: upstream router
- `services1`: management-services node at `192.168.99.10`
- `tacacs1`: TACACS+ server at `192.168.99.20`
- `client1`: DHCP client on VLAN 10
- `mgmt1`: admin workstation on VLAN 99 at `192.168.99.30`

## What Is Prebuilt

- base L2/L3 reachability
- management VLAN and user VLAN
- `services1` with dnsmasq, chrony, and rsyslog
- `tacacs1` with user `neteng`, password `labpass`, shared key `labkey`

## What You Configure

On `campus1`:

- DHCP relay toward `192.168.99.10`
- TACACS+ server group and AAA login
- NTP server `192.168.99.10`
- syslog host `192.168.99.10`
- SNMPv3 user and views
- optionally a `MGMT` VRF and management-plane routing separation

## Suggested Exercises

### 1. Fix DHCP for Users

`client1` starts as a DHCP client but does not have relay configured on the switch yet. Configure `ip helper-address 192.168.99.10` on `Vlan10`, then renew `client1`.

### 2. Move Device Administration to TACACS+

Point `campus1` at `tacacs1` with shared key `labkey`, user `neteng`, password `labpass`. Then test fallback to the local `admin` account if TACACS becomes unreachable.

### 3. Add Time and Logging

Configure NTP and syslog from `campus1` to `services1`, then inspect `/var/log/remote` on the server.

### 4. Upgrade SNMP from v2c Thinking to SNMPv3

Create a secure user on the switch and validate your config from `mgmt1`.

## Useful Commands

```bash
docker exec clab-enterprise-services-infra-client1 dhclient -r eth1
docker exec clab-enterprise-services-infra-client1 dhclient -v eth1
docker exec clab-enterprise-services-infra-services1 find /var/log/remote -maxdepth 1 -type f
docker exec clab-enterprise-services-infra-services1 tail -f /var/log/remote/campus1.log
```

On EOS:

```text
show ip interface brief
show running-config section aaa
show running-config section tacacs
show running-config section snmp
show ntp associations
show logging last 20
```

## What This Lab Teaches

- a network with working routing but broken services is still operationally broken
- device administration, logging, time, and inventory are management-plane design problems
- DHCP relay and centralized services are core enterprise skills, not side topics

## Extensions

These are optional follow-on ideas to deepen the lab. They are not part of the validated base workflow.

- Move management traffic into a dedicated VRF and verify each service still works with explicit source-interface and routing choices.
- Harden TACACS+ and SNMPv3 further, then deliberately break one component to validate local fallback and operational visibility.
- Add a config backup workflow from `mgmt1` so service health and device-state preservation are treated as one management-plane system.
- Compare syslog, SNMP, and TACACS accounting records for the same admin action to see what each source contributes.
