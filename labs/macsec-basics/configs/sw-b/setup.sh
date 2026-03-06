#!/bin/bash
# sw-b — right switch, participates in BOTH MACsec scenarios
#
# Scenario A (Infrastructure MACsec, this node):
#   eth2 <-> sw-a eth2
#   MACsec interface: macsec0 over eth2
#   IP: 192.168.1.2/30
#   CAK/CKN: infra group key (shared with sw-a)
#
# Scenario B (Endpoint MACsec, pass-through):
#   eth1 carries raw MKA EAPOL / MACsec frames for host-b.
#   Bridged macsec0 (infra link) ↔ eth1 (host-b side) so host-a↔host-b
#   endpoint MACsec frames traverse the encrypted infra link.

set -e

ip link set eth1 up
ip link set eth2 up

# ── Step 1: Start infra MACsec on eth2 (Scenario A) ──────────────────────

cat > /etc/wpa_supplicant-eth2.conf << 'EOF'
ctrl_interface=/var/run/wpa_supplicant
eapol_version=3

network={
    key_mgmt=NONE
    eap=NONE
    macsec_policy=1
    macsec_integrityonly=0
    mka_cak=0123456789abcdef0123456789abcdef
    mka_ckn=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
}
EOF

wpa_supplicant -D macsec_linux -i eth2 \
    -c /etc/wpa_supplicant-eth2.conf \
    -B -P /var/run/wpa-eth2.pid

echo "[sw-b] MKA started on eth2 (infra link, Scenario A)"

# Wait for MKA to elect key server and create the macsec interface
for i in $(seq 1 15); do
    if ip link show macsec0 >/dev/null 2>&1; then
        echo "[sw-b] macsec0 appeared after ${i}s"
        break
    fi
    sleep 1
done

if ! ip link show macsec0 >/dev/null 2>&1; then
    echo "[sw-b] WARNING: macsec0 not yet up — MKA may still be negotiating"
fi

ip link set macsec0 up 2>/dev/null || true
ip addr add 192.168.1.2/30 dev macsec0 2>/dev/null || true

echo "[sw-b] Infra MACsec: 192.168.1.2/30 on macsec0 over eth2"

# ── Step 2: Bridge macsec0 (infra link) ↔ eth1 (host-b) ─────────────────

ip link add name br0 type bridge 2>/dev/null || true
ip link set br0 up

# Move the infra IP off macsec0 onto br0
ip addr del 192.168.1.2/30 dev macsec0 2>/dev/null || true
ip addr add 192.168.1.2/30 dev br0 2>/dev/null || true

ip link set macsec0 master br0 2>/dev/null || true
ip link set eth1    master br0 2>/dev/null || true

echo "[sw-b] Bridge br0: macsec0 + eth1 — host traffic passes through infra link"
echo "[sw-b] Setup complete."
ip macsec show 2>/dev/null || true
ip addr show br0
