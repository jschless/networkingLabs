#!/usr/bin/env bash
# faults.sh — the troubleshooting finale (PLAN.md 4.2).
#
# Injects one planted, cross-layer fault into the RUNNING lab. In every case the
# layer where the symptom shows up is NOT the layer of the root cause — that's
# the whole point. Deploy the lab (./gcap.sh deploy), confirm it's healthy, then:
#
#   ./faults.sh inject <F1|F2|F3|F4>     break it
#   ./faults.sh clear  <F1|F2|F3|F4>     fix it
#   ./faults.sh list                     show the catalogue (no spoilers on cause)
#
# Work the symptom top-down before you peek at the cause in the README.
set -euo pipefail
P=clab-enterprise-grand-capstone
ceos() { docker exec -i "$P-$1" Cli -p15 >/dev/null 2>&1; }

case "${1:-list}::${2:-}" in

  # F1 — "Kerberos / AD is down": kinit hangs, mail + proxy SSO fail. But AD is
  # healthy and DNS resolves — the DC simply has no route back to the corporate
  # subnet, so its Kerberos replies are black-holed. (L3 routing -> presents as L7 auth.)
  inject::F1) docker exec dc1 ip route del 10.10.10.0/24 via 10.100.254.1 2>/dev/null || true
              echo "F1 injected: corp users report 'Kerberos is broken'." ;;
  clear::F1)  docker exec dc1 ip route replace 10.10.10.0/24 via 10.100.254.1
              echo "F1 cleared." ;;

  # F2 — "New laptop can't get on the network": 802.1X never completes, the port
  # stays quarantined. Looks like a supplicant/cert problem, but access-sw1's RADIUS
  # shared secret no longer matches radius1, so the server silently drops the request.
  # (Operate on an in-container COPY so the bind-mounted source file is never touched.)
  inject::F2) docker exec "$P-access-sw1" sh -c \
                'sed "s/=testing123/=wr0ng-secret/" /etc/hostapd/hostapd-corp.conf > /tmp/hostapd-bad.conf;
                 pkill hostapd 2>/dev/null; sleep 1;
                 hostapd -B -P /var/run/hostapd-eth2.pid /tmp/hostapd-bad.conf' >/dev/null 2>&1
              echo "F2 injected: corp-pc 802.1X fails (re-run the corp-pc supplicant to see it)." ;;
  clear::F2)  docker exec "$P-access-sw1" sh -c \
                'pkill hostapd 2>/dev/null; sleep 1;
                 hostapd -B -P /var/run/hostapd-eth2.pid /etc/hostapd/hostapd-corp.conf' >/dev/null 2>&1
              echo "F2 cleared (re-auth corp-pc)." ;;

  # F3 — "Phones in the voice VLAN get no IP" (data + guest VLANs are fine). Looks
  # like a phone/DHCP-client problem, but the VLAN-20 SVIs relay to the wrong helper
  # address, so the DISCOVER never reaches Kea. (L3 relay config -> presents as client.)
  inject::F3) for c in cc1 cc2; do ceos "$c" <<'EOF'
configure
interface Vlan20
no ip helper-address 10.100.30.10
ip helper-address 10.100.30.99
end
EOF
              done; echo "F3 injected: voip-phone gets no DHCP lease." ;;
  clear::F3)  for c in cc1 cc2; do ceos "$c" <<'EOF'
configure
interface Vlan20
no ip helper-address 10.100.30.99
ip helper-address 10.100.30.10
end
EOF
              done; echo "F3 cleared (re-run dhclient on voip-phone)." ;;

  # F4 — "Intermittent / half the users drop, services flap": the collapsed-core L2
  # peer-link is down, so VRRP dual-masters and return paths go asymmetric. Looks
  # like a service outage; it's a single shut L2 trunk. (L2 -> presents as app flapping.)
  inject::F4) ceos cc1 <<'EOF'
configure
interface Ethernet4
shutdown
end
EOF
              echo "F4 injected: peer-link down — VRRP dual-master / asymmetric paths." ;;
  clear::F4)  ceos cc1 <<'EOF'
configure
interface Ethernet4
no shutdown
end
EOF
              echo "F4 cleared." ;;

  list::*)
    cat <<'EOF'
Planted faults (cross-layer — symptom layer != cause layer):
  F1  "Kerberos / AD is down"      — corp kinit + SSO fail
  F2  "Can't get on the network"   — corp-pc 802.1X never completes
  F3  "Voice VLAN gets no IP"       — phones have no DHCP lease (data/guest fine)
  F4  "Intermittent partial outage" — services flap for some users
Usage: ./faults.sh inject <Fn> | clear <Fn>   (root cause + hints: README)
EOF
    ;;
  *) echo "usage: ./faults.sh {inject|clear} <F1|F2|F3|F4> | list"; exit 1 ;;
esac
