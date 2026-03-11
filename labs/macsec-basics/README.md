# macsec-basics — IEEE 802.1AE MACsec Lab

Demonstrates MACsec (Media Access Control Security) in two layered scenarios using Linux's `macsec_linux` driver and MKA (MACsec Key Agreement) via `wpa_supplicant`.

## Topology

```
[host-a] eth1 ──── eth1 [sw-a] eth2 ═══(MACsec A)═══ eth2 [sw-b] eth1 ──── eth1 [host-b]

═══ = encrypted MACsec link (Scenario A: infrastructure)
─── = plaintext wire (but carries Scenario B MACsec frames)
```

| Node   | Interface | IP             | Role                       |
|--------|-----------|----------------|----------------------------|
| host-a | macsec0   | 10.0.0.1/24    | Endpoint MACsec supplicant |
| sw-a   | macsec0   | 192.168.1.1/30 | Infrastructure MACsec      |
| sw-b   | macsec0   | 192.168.1.2/30 | Infrastructure MACsec      |
| host-b | macsec0   | 10.0.0.2/24    | Endpoint MACsec supplicant |

## Scenarios

### Scenario A — Infrastructure MACsec (sw-a ↔ sw-b)

Switch-to-switch link encryption using MKA with a pre-shared CAK (Connectivity Association Key). Both switches share the same CAK+CKN and MKA automatically elects a key server to derive SAKs (Secure Association Keys). Traffic between sw-a and sw-b is encrypted with GCM-AES-128.

### Scenario B — Endpoint MACsec (host-a ↔ host-b)

End-to-end host encryption. host-a and host-b share a different CAK+CKN pair. Their MACsec frames travel through sw-a and sw-b (which bridge them over the encrypted infra link), creating **nested MACsec** — host traffic is doubly protected.

## Build and Deploy

```bash
docker build -t macsec-lab:local labs/macsec-basics/
sudo containerlab deploy -t labs/macsec-basics/topology.clab.yml
```

## Verification

### Scenario A — Infrastructure Link

```bash
# Check MACsec status on sw-a
docker exec clab-macsec-basics-sw-a ip macsec show

# Check MKA statistics
docker exec clab-macsec-basics-sw-a ip -s macsec show macsec0

# See EtherType 0x88E5 (MACsec) on the wire — encrypted frames
docker exec clab-macsec-basics-sw-a tcpdump -i eth2 -n ether proto 0x88e5 -c 10

# Ping across the encrypted infra link
docker exec clab-macsec-basics-sw-a ping -c 3 192.168.1.2
```

### Scenario B — Endpoint-to-Endpoint

```bash
# Ping end-to-end (traverses infra MACsec transparently)
docker exec clab-macsec-basics-host-a ping -c 3 10.0.0.2

# On sw-a: watch the outer (infra) MACsec frames — host data is inside
docker exec clab-macsec-basics-sw-a tcpdump -i eth2 -n ether proto 0x88e5 -c 5

# On sw-a: watch on eth1 (host-a side) — inner MACsec frames visible on plaintext wire
docker exec clab-macsec-basics-sw-a tcpdump -i eth1 -n ether proto 0x88e5 -c 5
```

### Observe MKA Key Exchange

```bash
# Watch MKA EAPOL frames during startup (EtherType 0x888e)
docker exec clab-macsec-basics-sw-a tcpdump -i eth2 -n ether proto 0x888e -c 20
```

## Key Concepts

| Concept | Details |
|---------|---------|
| **EtherType** | 0x88E5 (MACsec); 0x888E (EAPoL/MKA) |
| **CAK** | Connectivity Association Key — pre-shared secret (16 bytes) |
| **CKN** | CAK Name — identifies the CAK (32 bytes) |
| **MKA** | MACsec Key Agreement — IEEE 802.1X-2010 protocol |
| **SAK** | Secure Association Key — derived by key server, rotated periodically |
| **SecTAG** | 8-byte header added by MACsec |
| **ICV** | 16-byte Integrity Check Value (GCM authentication tag) |
| **Overhead** | 24 bytes per frame (SecTAG + ICV) |
| **Cipher** | GCM-AES-128 (confidentiality + integrity) |

## Exploration Tasks

1. **Watch SAK rotation**: `wpa_cli -i eth2 -p /var/run/wpa_supplicant status` on sw-a
2. **Verify encryption**: capture on eth2 (encrypted) vs eth1 (plaintext inner MAC frames)
3. **Check frame counters**: `ip -s macsec show macsec0` — watch `txsc` and `rxsc` counts grow
4. **Nested MACsec**: use Wireshark/tcpdump to show the outer MACsec frame concealing the inner one
5. **Break it**: stop wpa_supplicant on one end and observe traffic stops (MACsec strictly enforced)

## Build Note

The `macsec_linux` kernel module must be available on the host. Verify with:
```bash
modprobe macsec && echo "MACsec module available"
```
