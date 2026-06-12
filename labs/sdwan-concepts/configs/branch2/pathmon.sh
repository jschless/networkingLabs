#!/bin/sh
# pathmon — see configs/branch1/pathmon.sh for the full commentary.
# branch2 mirror: probes branch1's MPLS-tunnel address, steers 10.1.0.0/24.

PEER=10.255.1.1          # MPLS-tunnel peer (branch1)
REMOTE_LAN=10.1.0.0/24
PRIMARY_NH=10.255.1.1    # tun-mpls
BACKUP_NH=10.255.2.1     # tun-inet
TABLE=100
THRESHOLD=3
# See configs/branch1/pathmon.sh for why the underlay route is re-pinned.
UNDERLAY_NET=172.16.1.0/30
UNDERLAY_NH=172.16.2.2

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
