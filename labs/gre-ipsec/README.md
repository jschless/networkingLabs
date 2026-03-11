# Lab: gre-ipsec

## Purpose
Learn GRE-over-IPsec — the classic enterprise WAN pattern that combines GRE tunnels (for
routing protocol support) with IPsec transport mode (for encryption). Understand why this
combination is used instead of plain IPsec (no routing protocol support) or plain GRE
(no encryption), and how IPsec transport mode encrypts GRE without double-encapsulation.

## Topology

```
[host-a] --- [gw-a] ---WAN--- [internet] ---WAN--- [gw-b] --- [host-b]
192.168.1.10  .1  203.0.113.1 203.0.113.2  203.0.113.5 203.0.113.6  .1  192.168.2.10
```

| Segment | Network | Addresses |
|---------|---------|-----------|
| LAN A | 192.168.1.0/24 | host-a=.10, gw-a=.1 |
| WAN A | 203.0.113.0/30 | gw-a=.1, internet=.2 |
| WAN B | 203.0.113.4/30 | internet=.5, gw-b=.6 |
| LAN B | 192.168.2.0/24 | gw-b=.1, host-b=.10 |
| GRE tunnel | 172.16.0.0/30 | gw-a tun0=.1, gw-b tun0=.2 |

## Prerequisites: Build the IPsec Image

The gw-a and gw-b nodes use a custom image with strongSwan installed:

```bash
docker build -t ipsec-lab:local labs/ipsec-basics/
```

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.clab.yml
sudo containerlab destroy -t topology.clab.yml
```

## What Is Pre-Configured

The `setup.sh` scripts on gw-a and gw-b automatically configure:
- All interface IP addresses
- Default routes
- **GRE tunnel (tun0)** between 203.0.113.1 and 203.0.113.6
- GRE tunnel addresses (172.16.0.1/30 on gw-a, 172.16.0.2/30 on gw-b)
- Static routes for LAN B via GRE (and LAN A on gw-b)

After deploy, GRE is working — you can ping across it **unencrypted**. Your task is to
add IPsec to encrypt the GRE traffic.

## What You Configure

### Step 1: Verify GRE works (before IPsec)

```bash
# Ping across GRE from gw-a to gw-b tunnel endpoint
docker exec clab-gre-ipsec-gw-a ping -c3 172.16.0.2

# Ping host-to-host across GRE
docker exec clab-gre-ipsec-host-a ping -c3 192.168.2.10
```

Capture traffic on WAN to see GRE plaintext:
```bash
docker exec clab-gre-ipsec-internet tcpdump -i eth1 -n proto 47
```
You should see unencrypted GRE packets (protocol 47).

### Step 2: Configure IPsec on gw-a

IPsec transport mode encrypts the payload of IP packets (the GRE data) while preserving
the outer IP header. This is ideal for GRE because the outer IP header (gw-a to gw-b) is
preserved, only the GRE contents are encrypted.

Edit `/etc/ipsec.conf` on gw-a:
```bash
docker exec -it clab-gre-ipsec-gw-a bash
cat > /etc/ipsec.conf << 'EOF'
config setup
    charondebug="ike 1, knl 1, cfg 0"

conn gre-ipsec
    type=transport
    authby=secret
    left=203.0.113.1
    leftprotoport=gre
    right=203.0.113.6
    rightprotoport=gre
    keyexchange=ikev2
    auto=start
EOF
```

Edit `/etc/ipsec.secrets`:
```bash
cat > /etc/ipsec.secrets << 'EOF'
203.0.113.1 203.0.113.6 : PSK "SuperSecret123"
EOF
```

### Step 3: Configure IPsec on gw-b

```bash
docker exec -it clab-gre-ipsec-gw-b bash
cat > /etc/ipsec.conf << 'EOF'
config setup
    charondebug="ike 1, knl 1, cfg 0"

conn gre-ipsec
    type=transport
    authby=secret
    left=203.0.113.6
    leftprotoport=gre
    right=203.0.113.1
    rightprotoport=gre
    keyexchange=ikev2
    auto=start
EOF

cat > /etc/ipsec.secrets << 'EOF'
203.0.113.6 203.0.113.1 : PSK "SuperSecret123"
EOF
```

### Step 4: Start IPsec on both gateways

```bash
docker exec clab-gre-ipsec-gw-a ipsec start
docker exec clab-gre-ipsec-gw-b ipsec start
```

Wait a few seconds for IKE negotiation, then check:
```bash
docker exec clab-gre-ipsec-gw-a ipsec status
```

### Step 5: Verify encryption

Test connectivity (should still work):
```bash
docker exec clab-gre-ipsec-host-a ping -c3 192.168.2.10
```

Capture WAN traffic (should now see ESP, not GRE):
```bash
docker exec clab-gre-ipsec-internet tcpdump -i eth1 -n proto 50
# proto 50 = ESP (Encapsulating Security Payload)
```
You should now see **ESP packets** instead of raw GRE.

## Verification Commands

```bash
# IPsec status and SA details
docker exec clab-gre-ipsec-gw-a ipsec status
docker exec clab-gre-ipsec-gw-a ipsec statusall

# Kernel IPsec policies (xfrm)
docker exec clab-gre-ipsec-gw-a ip xfrm policy
docker exec clab-gre-ipsec-gw-a ip xfrm state

# GRE tunnel status
docker exec clab-gre-ipsec-gw-a ip tunnel show

# Capture ESP on WAN A
docker exec clab-gre-ipsec-internet tcpdump -i eth1 -n

# Ping test (host-to-host)
docker exec clab-gre-ipsec-host-a ping -c3 192.168.2.10
```

## Concepts

### Why GRE + IPsec?

| Feature | Plain GRE | Plain IPsec | GRE + IPsec |
|---------|-----------|-------------|-------------|
| Encryption | No | Yes | Yes |
| Routing protocols (OSPF/BGP) | Yes | No* | Yes |
| Multicast support | Yes | No | Yes |
| Configuration complexity | Low | Medium | Medium |

*IPsec tunnel mode can carry routing protocols but the session is point-to-point
and doesn't support multicast naturally.

### IPsec Transport vs Tunnel Mode

**Tunnel mode** (standard IPsec): Adds a new outer IP header. Creates a new virtual
tunnel between two IPs. The original IP packet is completely encapsulated.

**Transport mode** (used here): Encrypts only the payload of the original IP packet.
The outer IP header (source/dest IPs) remains visible. Used when the outer IP already
identifies the two VPN endpoints (which is the case when we want to encrypt GRE packets
between gw-a and gw-b).

```
GRE transport mode IPsec packet:
[IP: 203.0.113.1 -> 203.0.113.6][ESP][GRE encrypted payload]

vs. IPsec tunnel mode:
[IP: 203.0.113.1 -> 203.0.113.6][ESP][IP: 192.168.1.x -> 192.168.2.x][TCP/data]
```

### Protecting Proto 47 (GRE)

The IPsec policy `leftprotoport=gre` / `rightprotoport=gre` targets protocol 47 (GRE)
specifically. This means: only GRE packets between these two IPs are protected by IPsec.
Other traffic (like ICMP between the WAN IPs) is not encrypted.

## Challenge Exercises

1. Use `tcpdump` on the internet node before and after enabling IPsec. Capture the
   IKE (UDP port 500) handshake and the subsequent ESP-encrypted GRE traffic.

2. Add OSPF over the GRE tunnel. Configure OSPF on gw-a and gw-b using tun0,
   and advertise the LAN networks. Does OSPF run over the encrypted tunnel?

3. Modify the IPsec config to use IKEv1 instead of IKEv2 (`keyexchange=ikev1`).
   What changes in `ipsec statusall`?

4. Try using a certificate-based authentication (`authby=rsasig`) instead of PSK.
   What additional configuration is needed?

5. Break IPsec by changing the PSK on one side. What happens to GRE connectivity?
   Does traffic fall back to unencrypted GRE, or does it stop entirely?
