#!/bin/bash
# vlan-action.sh — hostapd_cli action handler (grand capstone).
# Called on 802.1X events on access-sw1's eth2. On auth success the corp port is
# moved from the quarantine VLAN (99) to the corporate VLAN (10) and unblocked;
# on disconnect/failure it falls back to quarantine. The RADIUS server also
# returns Tunnel-Private-Group-Id=10 (visible in radius1's log) — this script is
# how the authenticator acts on that assignment.

INTERFACE="$1"
EVENT="$2"

log() { echo "[vlan-action] $*" | tee -a /var/log/vlan-action.log; }

case "$INTERFACE" in
    eth2) AUTH_VLAN=10 ;;   # corp-pc -> corporate
    *)    AUTH_VLAN="" ;;
esac

case "$EVENT" in
    AP-STA-CONNECTED*)
        [ -z "$AUTH_VLAN" ] && { log "$INTERFACE: no VLAN mapping"; exit 0; }
        log "$INTERFACE: auth success -> VLAN $AUTH_VLAN"
        bridge vlan del dev "$INTERFACE" vid 99 2>/dev/null || true
        bridge vlan add dev "$INTERFACE" vid "$AUTH_VLAN" pvid untagged master
        nft delete element bridge nac blocked_ifaces "{ \"$INTERFACE\" }" 2>/dev/null || true
        log "$INTERFACE: now on VLAN $AUTH_VLAN — open"
        ;;
    AP-STA-DISCONNECTED*|CTRL-EVENT-EAP-FAILURE*)
        log "$INTERFACE: down/fail -> quarantine VLAN 99"
        for v in 10 20 30; do bridge vlan del dev "$INTERFACE" vid $v 2>/dev/null || true; done
        bridge vlan add dev "$INTERFACE" vid 99 pvid untagged master
        nft add element bridge nac blocked_ifaces "{ \"$INTERFACE\" }" 2>/dev/null || true
        ;;
esac
