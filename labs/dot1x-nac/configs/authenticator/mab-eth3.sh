#!/bin/bash
# mab-eth3.sh — MAC Authentication Bypass for eth3
#
# Simulates what a real NAC switch does for non-802.1X devices:
# 1. Wait for any Ethernet frame from the device on eth3
# 2. Extract its source MAC address
# 3. Send RADIUS Access-Request with MAC as User-Name and User-Password
# 4. On Accept: move eth3 from quarantine VLAN 99 to VLAN 30 (IoT)
#
# Run automatically by setup.sh in background, or manually:
#   docker exec clab-dot1x-nac-authenticator bash /etc/hostapd/mab-eth3.sh

LOG=/var/log/mab-eth3.log

log() { echo "[mab-eth3] $*" | tee -a "$LOG"; }

log "Starting — waiting for first Ethernet frame on eth3 (timeout 90s)"

# Capture the source MAC of the first unicast frame from eth3.
# tcpdump uses raw sockets below the bridge, so it sees frames even if
# the ebtables FORWARD DROP rule would block them from being bridged.
RAW_LINE=$(timeout 90 tcpdump -i eth3 -c 1 -e -n \
    'not ether broadcast and not ether multicast' 2>/dev/null || true)

if [ -z "$RAW_LINE" ]; then
    log "No unicast frame received within 90s — giving up"
    exit 1
fi

# Extract source MAC (first MAC in the tcpdump -e output line)
MAC_COLON=$(echo "$RAW_LINE" | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
if [ -z "$MAC_COLON" ]; then
    log "Could not parse MAC from: $RAW_LINE"
    exit 1
fi

# Normalise: lowercase, no separators (format expected by RADIUS)
MAC=$(echo "$MAC_COLON" | tr -d ':' | tr 'A-Z' 'a-z')
log "Detected source MAC: $MAC_COLON  (normalised: $MAC)"

# Send RADIUS Access-Request (MAB: MAC as both User-Name and User-Password)
log "Sending RADIUS Access-Request (User-Name=$MAC) to 192.168.100.2..."
RESPONSE=$(printf 'User-Name=%s\nUser-Password=%s\nNAS-IP-Address=192.168.100.1\nCalling-Station-Id=%s\nCalled-Station-Id=mab\n' \
    "$MAC" "$MAC" "$MAC_COLON" | \
    radclient -x 192.168.100.2:1812 auth testing123 2>&1 || true)

log "RADIUS response:"
echo "$RESPONSE" | tee -a "$LOG"

if echo "$RESPONSE" | grep -q "Access-Accept"; then
    log "Access-Accept → moving eth3 from VLAN 99 to VLAN 30"
    bridge vlan del dev eth3 vid 99  2>/dev/null || true
    bridge vlan add dev eth3 vid 30 pvid untagged master
    ebtables -D FORWARD -i eth3 -j DROP 2>/dev/null || true
    log "eth3 is now on VLAN 30 — supplicant-mab can reach iot-server (10.30.30.1)"
else
    log "No Access-Accept — eth3 stays quarantined on VLAN 99"
fi
