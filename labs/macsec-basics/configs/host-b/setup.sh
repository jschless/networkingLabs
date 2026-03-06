#!/bin/bash
# host-b — endpoint MACsec supplicant (Scenario B)
#
# MACsec session: host-a ↔ host-b (end-to-end encryption)
# Physical path:  host-b:eth1 → sw-b:eth1 → (infra MACsec) → sw-a:eth1 → host-a:eth1
#
# Same CAK/CKN as host-a — they form one MKA Connectivity Association (CA).

set -e

ip link set eth1 up

cat > /etc/wpa_supplicant-eth1.conf << 'EOF'
ctrl_interface=/var/run/wpa_supplicant
eapol_version=3

network={
    key_mgmt=NONE
    eap=NONE
    macsec_policy=1
    macsec_integrityonly=0
    mka_cak=aabbccddeeff00112233445566778899
    mka_ckn=aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899
}
EOF

wpa_supplicant -D macsec_linux -i eth1 \
    -c /etc/wpa_supplicant-eth1.conf \
    -B -P /var/run/wpa-eth1.pid

echo "[host-b] MKA started on eth1 — waiting for macsec0 interface..."

for i in $(seq 1 20); do
    if ip link show macsec0 >/dev/null 2>&1; then
        echo "[host-b] macsec0 appeared after ${i}s"
        break
    fi
    sleep 1
done

ip link set macsec0 up 2>/dev/null || true
ip addr add 10.0.0.2/24 dev macsec0 2>/dev/null || true

echo "[host-b] Endpoint MACsec ready: 10.0.0.2/24 on macsec0"
echo "[host-b] Test: ping 10.0.0.1"
ip macsec show 2>/dev/null || true
