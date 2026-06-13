#!/bin/bash
# corp-pc — corporate workstation on access-sw1 eth2.
# 802.1X supplicant: PEAP/MSCHAPv2 as AD user `bob`. Once hostapd accepts the
# Access-Accept, the access port moves to VLAN 10 and a DHCP lease can be pulled
# from the real Kea server (see the README verification steps: `dhclient eth1`).
set -e

ip link set eth1 up

# Drop the ContainerLab management default route (via eth0) so campus traffic is
# routed through the access network, not the mgmt bridge. dhclient will install
# the real default (via the VLAN-10 VRRP gateway) once a lease is obtained.
ip route del default via 172.20.20.1 dev eth0 2>/dev/null || true

mkdir -p /etc/wpa_supplicant
cat > /etc/wpa_supplicant/wpa.conf <<'EOF'
ctrl_interface=/var/run/wpa_supplicant
network={
    key_mgmt=IEEE8021X
    eap=PEAP
    identity="bob"
    password="P@ssw0rd1"
    phase2="auth=MSCHAPV2"
    eapol_flags=0
}
EOF

# Kerberos client config so `kinit bob` works once the host is on the network
# (used by the F1 "Kerberos is broken" troubleshooting scenario).
cat > /etc/krb5.conf <<'EOF'
[libdefaults]
    default_realm = LAB.CORP
    dns_lookup_realm = false
    dns_lookup_kdc = true
    rdns = false
[realms]
    LAB.CORP = {
        kdc = dc1.lab.corp
        admin_server = dc1.lab.corp
    }
EOF

# Start the supplicant; the port authorizes into VLAN 10.
wpa_supplicant -D wired -i eth1 -c /etc/wpa_supplicant/wpa.conf -B -f /var/log/wpa.log
echo "[corp-pc] 802.1X supplicant started (PEAP, bob). Next: dhclient eth1"
