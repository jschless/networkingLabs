#!/bin/bash
# sw-a — left switch, participates in BOTH MACsec scenarios
#
# Scenario A (Infrastructure MACsec, this node):
#   eth2 <-> sw-b eth2
#   MACsec interface: macsec0 over eth2
#   IP: 192.168.1.1/30
#   CAK/CKN: infra group key (shared with sw-b)
#
# Scenario B (Endpoint MACsec, pass-through):
#   eth1 carries raw MKA EAPOL frames between host-a and sw-a's eth1.
#   sw-a is NOT a MACsec endpoint for the host link — it just bridges/
#   forwards Ethernet frames on eth1 without terminating MACsec.
#   (The MACsec session is between host-a and host-b end-to-end.)
#
# NOTE: eth1 is left as a plain L2 forwarder. The MKA handshake between
# host-a and host-b passes through sw-a's eth1 transparently because
# MACsec is transparent to unknown EtherTypes on a plain Linux bridge.
# We add eth1 to a bridge so frames pass from host-a side through to
# sw-b and on to host-b.

set -e

ip link set eth1 up
ip link set eth2 up

# --- Scenario B pass-through bridge ---
# Bridge eth1 (host-a side) to eth2-side? No — eth2 is used for infra
# MACsec (Scenario A). The host-a↔host-b MACsec session traverses:
#   host-a:eth1 → sw-a:eth1 → sw-a:eth2 (wire) → sw-b:eth2 → sw-b:eth1 → host-b:eth1
# But eth2 is used for the sw-a↔sw-b infra MACsec. To allow host traffic
# to traverse the sw-a↔sw-b link AND keep the infra MACsec on that link,
# we need to bridge carefully.
#
# Practical approach for this lab:
#   - Infra MACsec (Scenario A) terminates at sw-a and sw-b on macsec0.
#   - Host endpoint MACsec (Scenario B) runs directly over eth1 on each host.
#     host-a:eth1 is directly connected to sw-a:eth1 (one link).
#     host-b:eth1 is directly connected to sw-b:eth1 (one link).
#     There is NO direct wire between host-a and host-b — traffic must pass
#     through the sw-a↔sw-b link.
#
# Therefore we bridge:
#   - On sw-a: eth1 <-> macsec0  (so host-a's MKA frames ride over the
#              encrypted infra link to sw-b, then reach host-b:eth1)
#   - On sw-b: macsec0 <-> eth1  (symmetric)
#
# This means the Scenario B MACsec session (host-a↔host-b) is NESTED inside
# the Scenario A MACsec session (sw-a↔sw-b). All host-a↔host-b frames are
# doubly protected: outer MACsec (infra) + inner MACsec (endpoint).

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

echo "[sw-a] MKA started on eth2 (infra link, Scenario A)"

# Wait for MKA to elect key server and create the macsec interface
for i in $(seq 1 15); do
    if ip link show macsec0 >/dev/null 2>&1; then
        echo "[sw-a] macsec0 appeared after ${i}s"
        break
    fi
    sleep 1
done

if ! ip link show macsec0 >/dev/null 2>&1; then
    echo "[sw-a] WARNING: macsec0 not yet up — MKA may still be negotiating"
fi

ip link set macsec0 up 2>/dev/null || true
ip addr add 192.168.1.1/30 dev macsec0 2>/dev/null || true

echo "[sw-a] Infra MACsec: 192.168.1.1/30 on macsec0 over eth2"

# ── Step 2: Bridge eth1 (host-a) ↔ macsec0 (infra link) ─────────────────
# This lets host-a↔host-b MACsec frames traverse the encrypted infra link.

ip link add name br0 type bridge 2>/dev/null || true
ip link set br0 up

# Move the infra IP off macsec0 onto br0 so it stays reachable after
# enslaving macsec0 into the bridge.
ip addr del 192.168.1.1/30 dev macsec0 2>/dev/null || true
ip addr add 192.168.1.1/30 dev br0 2>/dev/null || true

ip link set eth1   master br0 2>/dev/null || true
ip link set macsec0 master br0 2>/dev/null || true

echo "[sw-a] Bridge br0: eth1 + macsec0 — host traffic passes through infra link"
echo "[sw-a] Setup complete."
ip macsec show 2>/dev/null || true
ip addr show br0
