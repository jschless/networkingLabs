# Lab: wireguard

## Purpose
Learn WireGuard — a modern, high-performance VPN built into the Linux kernel. Understand
WireGuard's public-key cryptography model, how to configure a hub-and-spoke VPN, and how
WireGuard compares to traditional VPN protocols (IPsec, OpenVPN) in terms of simplicity,
performance, and attack surface.

## Topology

```
  [gw-a]                         [gw-b]
  WAN: 10.0.0.10                 WAN: 10.0.0.20
  wg0: 192.168.100.10            wg0: 192.168.100.20
        \                              /
         \-------- [br-wan] ----------/
                       |
                    [hub]
                    WAN: 10.0.0.1
                    wg0: 192.168.100.1
```

| Node | WAN IP | WireGuard IP | Role |
|------|--------|--------------|------|
| hub  | 10.0.0.1/24  | 192.168.100.1/24  | VPN server (always listening) |
| gw-a | 10.0.0.10/24 | 192.168.100.10/32 | Site A gateway (client) |
| gw-b | 10.0.0.20/24 | 192.168.100.20/32 | Site B gateway (client) |

## Prerequisites: Build the Image

WireGuard tools are not in the standard FRR image. Build a custom image first:

```bash
docker build -t wireguard-lab:local labs/wireguard/
```

## Deploy / Destroy

```bash
# Build image first (only needed once)
docker build -t wireguard-lab:local labs/wireguard/

sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml --cleanup
```

## What You Configure

WAN IPs are pre-configured by setup.sh. Your task is to generate WireGuard key pairs
and configure `/etc/wireguard/wg0.conf` on each node.

### Step 1: Generate key pairs on each node

```bash
# Generate hub key pair
docker exec clab-wireguard-hub bash -c \
  'wg genkey | tee /etc/wireguard/hub.key | wg pubkey > /etc/wireguard/hub.pub'

# Print hub public key (you'll need this for client configs)
docker exec clab-wireguard-hub cat /etc/wireguard/hub.pub

# Generate gw-a key pair
docker exec clab-wireguard-gw-a bash -c \
  'wg genkey | tee /etc/wireguard/gwa.key | wg pubkey > /etc/wireguard/gwa.pub'
docker exec clab-wireguard-gw-a cat /etc/wireguard/gwa.pub

# Generate gw-b key pair
docker exec clab-wireguard-gw-b bash -c \
  'wg genkey | tee /etc/wireguard/gwb.key | wg pubkey > /etc/wireguard/gwb.pub'
docker exec clab-wireguard-gw-b cat /etc/wireguard/gwb.pub
```

Note the three public keys — you need them for the peer configurations.

### Step 2: Configure hub

Replace `GWA_PUBKEY` and `GWB_PUBKEY` with the actual public keys from Step 1.

```bash
docker exec clab-wireguard-hub bash -c 'cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/hub.key)
Address = 192.168.100.1/24
ListenPort = 51820

[Peer]
# gw-a (Site A)
PublicKey = GWA_PUBKEY
AllowedIPs = 192.168.100.10/32

[Peer]
# gw-b (Site B)
PublicKey = GWB_PUBKEY
AllowedIPs = 192.168.100.20/32
EOF'
```

### Step 3: Configure gw-a

Replace `HUB_PUBKEY` with hub's public key from Step 1.

```bash
docker exec clab-wireguard-gw-a bash -c 'cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/gwa.key)
Address = 192.168.100.10/32

[Peer]
# hub
PublicKey = HUB_PUBKEY
Endpoint = 10.0.0.1:51820
AllowedIPs = 192.168.100.0/24
PersistentKeepalive = 25
EOF'
```

### Step 4: Configure gw-b

```bash
docker exec clab-wireguard-gw-b bash -c 'cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/gwb.key)
Address = 192.168.100.20/32

[Peer]
# hub
PublicKey = HUB_PUBKEY
Endpoint = 10.0.0.1:51820
AllowedIPs = 192.168.100.0/24
PersistentKeepalive = 25
EOF'
```

### Step 5: Start WireGuard on all nodes

```bash
docker exec clab-wireguard-hub wg-quick up wg0
docker exec clab-wireguard-gw-a wg-quick up wg0
docker exec clab-wireguard-gw-b wg-quick up wg0
```

### Step 6: Verify

```bash
# Hub status (should show 2 peers, handshake times after traffic)
docker exec clab-wireguard-hub wg show

# Ping gw-a from hub via WireGuard tunnel
docker exec clab-wireguard-hub ping -c3 192.168.100.10

# Ping gw-b from hub
docker exec clab-wireguard-hub ping -c3 192.168.100.20

# Ping gw-b from gw-a (traffic goes through hub in hub-and-spoke)
docker exec clab-wireguard-gw-a ping -c3 192.168.100.20
```

## Verification Commands

```bash
# Show WireGuard interface status (peers, allowed IPs, handshake, traffic)
docker exec clab-wireguard-hub wg show

# Show specific interface detail
docker exec clab-wireguard-hub wg show wg0

# Show WireGuard interface via ip
docker exec clab-wireguard-hub ip addr show wg0

# Show routes added by wg-quick (AllowedIPs become routes)
docker exec clab-wireguard-hub ip route show

# Capture WireGuard UDP traffic on WAN
docker exec clab-wireguard-hub tcpdump -i eth1 -n udp port 51820 -c5
```

## Concepts

### Cryptography Model

WireGuard uses modern, fixed cryptographic primitives (no negotiation):
- **Curve25519** for key exchange (ECDH)
- **ChaCha20-Poly1305** for authenticated encryption
- **BLAKE2s** for hashing
- **SipHash24** for hashtable keys

Each device has a static **private key** and derived **public key**. Peers are identified
only by their public key — there are no usernames, passwords, or certificates.

### Key Concepts

**Private key**: Never leaves the device. Generated with `wg genkey`.
**Public key**: Derived from private key with `wg pubkey`. Shared with peers.
**Endpoint**: Optional. If set, this peer initiates connections to that IP:port.
             Servers typically have no Endpoint (they listen). Clients set Endpoint to server.

**AllowedIPs**: Serves two purposes:
1. **Outbound routing**: Traffic to these IPs is encrypted and sent to this peer
2. **Inbound filtering**: Only packets claiming to be from these IPs are accepted from this peer

**PersistentKeepalive**: Sends a keepalive packet every N seconds. Needed for clients
behind NAT to maintain the NAT mapping. Set on clients, not on the server.

### Hub-and-Spoke vs Mesh

This lab is **hub-and-spoke**: gw-a to gw-b traffic routes through hub.

For direct gw-a to gw-b connectivity, each would need the other as a peer with
the correct AllowedIPs and Endpoint. That's a **mesh** topology.

### WireGuard vs IPsec vs OpenVPN

| Feature | WireGuard | IPsec | OpenVPN |
|---------|-----------|-------|---------|
| Lines of code | ~4,000 | Massive | Large |
| Config complexity | Minimal | High | Medium |
| Key management | Public key pairs | Certs or PSK | Certs or PSK |
| Protocol | UDP custom | ESP/AH (IPsec SAs) | UDP/TCP TLS |
| Performance | Excellent | Good | Moderate |
| Kernel integration | Yes (kernel module) | Yes (xfrm) | No (userspace) |
| Standard compliance | No (proprietary) | RFC standards | No |

### How wg-quick Works

`wg-quick up wg0` reads `/etc/wireguard/wg0.conf` and:
1. Creates the `wg0` kernel network interface
2. Sets the private key and listen port
3. Configures each peer (public key, allowed IPs, endpoint)
4. Adds routes for each peer's `AllowedIPs`
5. Brings the interface up

`wg-quick down wg0` reverses this.

## Challenge Exercises

1. Capture WireGuard traffic: `docker exec clab-wireguard-hub tcpdump -i eth1 -n udp port 51820`.
   Note that the payload is completely opaque (encrypted). Compare to unencrypted OSPF or BGP traffic.

2. Add site subnets behind the gateways. On gw-a, add a loopback `ip addr add 192.168.10.1/24 dev lo`.
   Update hub's AllowedIPs for gw-a to include `192.168.10.0/24`. Verify hub can ping 192.168.10.1.

3. Configure direct spoke-to-spoke connectivity: add gw-b as a peer on gw-a (with Endpoint and
   AllowedIPs 192.168.100.20/32). After bringing tunnels up, does ping from gw-a to gw-b go
   directly or still through hub? (Check `wg show` to see which peer the packet uses.)

4. Remove `PersistentKeepalive` from gw-a and observe: does the tunnel come up without it?
   (Yes, if gw-a initiates traffic to hub.) When would `PersistentKeepalive` be required?

5. Use `wg show` after successful tunnels are established. Examine the `latest handshake` field.
   Initiate traffic and watch the `transfer` counters increment. Notice handshake re-keys
   automatically every ~3 minutes (WireGuard's default rekey interval).
