#!/bin/sh
# pathmon — hand-rolled stand-in for SD-WAN BFD path probes + app-route policy.
#
# Pings the MPLS-tunnel peer once a second. Three consecutive losses =
# transport declared dead -> the voice route (table 100) is repointed at the
# internet tunnel. Three consecutive successes = restore the preferred path.
#
# What it does NOT measure — per-packet loss %, latency, jitter against an
# SLA class — is exactly the gap between blackout detection and real
# app-route SLA enforcement. Demo 4 in the README rubs this in.

PEER=10.255.1.2          # MPLS-tunnel peer (branch2)
REMOTE_LAN=10.2.0.0/24
PRIMARY_NH=10.255.1.2    # tun-mpls
BACKUP_NH=10.255.2.2     # tun-inet
TABLE=100
THRESHOLD=3
# Static underlay route to the far end's MPLS WAN subnet. The kernel
# flushes it when the WAN link flaps; a real router's routing protocol
# would re-learn it, so the monitor re-pins it each cycle instead.
UNDERLAY_NET=172.16.2.0/30
UNDERLAY_NH=172.16.1.2

fails=0
oks=0
state=primary

log() { echo "$(date '+%H:%M:%S') $*"; }

log "pathmon start: probing $PEER every 1s (threshold $THRESHOLD)"

while true; do
    ip route replace "$UNDERLAY_NET" via "$UNDERLAY_NH" 2>/dev/null
    if ping -c 1 -W 1 "$PEER" >/dev/null 2>&1; then
        oks=$((oks + 1)); fails=0
        if [ "$state" = "backup" ] && [ "$oks" -ge "$THRESHOLD" ]; then
            ip route replace "$REMOTE_LAN" via "$PRIMARY_NH" table "$TABLE"
            state=primary
            log "RESTORE: $THRESHOLD probes OK — voice back on tun-mpls ($PRIMARY_NH)"
        fi
    else
        fails=$((fails + 1)); oks=0
        if [ "$state" = "primary" ] && [ "$fails" -ge "$THRESHOLD" ]; then
            ip route replace "$REMOTE_LAN" via "$BACKUP_NH" table "$TABLE"
            state=backup
            log "FAILOVER: $THRESHOLD probes lost — voice moved to tun-inet ($BACKUP_NH)"
        fi
    fi
    sleep 1
done
