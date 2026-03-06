#!/bin/bash
# vlan-action.sh — called by hostapd_cli -a when 802.1X events occur.
#
# Arguments:
#   $1 = interface name (eth1, eth2, eth3, eth4)
#   $2 = event string  (e.g., "AP-STA-CONNECTED aa:bb:cc:dd:ee:ff")
#
# Interface → VLAN mapping (matches RADIUS VLAN attributes):
#   eth1 (supplicant-tls)  → VLAN 10 (employee)
#   eth2 (supplicant-peap) → VLAN 20 (contractor)
#   eth3 (supplicant-mab)  → VLAN 30 (IoT)
#   eth4 (supplicant-fail) → stays VLAN 99 (auth will fail)

INTERFACE="$1"
EVENT="$2"

log() {
    echo "[vlan-action] $*" | tee -a /var/log/vlan-action.log
}

case "$INTERFACE" in
    eth1) AUTH_VLAN=10 ;;
    eth2) AUTH_VLAN=20 ;;
    eth3) AUTH_VLAN=30 ;;
    *)    AUTH_VLAN=""  ;;
esac

case "$EVENT" in
    AP-STA-CONNECTED*)
        if [ -z "$AUTH_VLAN" ]; then
            log "$INTERFACE: auth success but no VLAN mapping (staying quarantined)"
            exit 0
        fi
        log "$INTERFACE: auth success → moving to VLAN $AUTH_VLAN"

        # Move bridge port from quarantine VLAN 99 to authenticated VLAN
        bridge vlan del dev "$INTERFACE" vid 99 2>/dev/null || true
        bridge vlan add dev "$INTERFACE" vid "$AUTH_VLAN" pvid untagged master

        # Remove the pre-auth DROP rule for this interface
        ebtables -D FORWARD -i "$INTERFACE" -j DROP 2>/dev/null || true

        log "$INTERFACE: now on VLAN $AUTH_VLAN — port open for traffic"
        ;;

    AP-STA-DISCONNECTED*)
        log "$INTERFACE: station disconnected → reverting to VLAN 99 (quarantine)"

        # Revert port to quarantine VLAN on disconnect
        for v in 10 20 30; do
            bridge vlan del dev "$INTERFACE" vid $v 2>/dev/null || true
        done
        bridge vlan add dev "$INTERFACE" vid 99 pvid untagged master

        # Re-add pre-auth DROP rule
        # (delete first to avoid duplicates, then re-add)
        ebtables -D FORWARD -i "$INTERFACE" -j DROP 2>/dev/null || true
        ebtables -A FORWARD -i "$INTERFACE" -j DROP

        log "$INTERFACE: reverted to VLAN 99 quarantine"
        ;;

    CTRL-EVENT-EAP-FAILURE*)
        log "$INTERFACE: EAP failure — port remains quarantined on VLAN 99"
        ;;
esac
