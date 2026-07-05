#!/bin/sh
# conntrackd primary-backup glue — the standard conntrack-tools state
# machine, shipped as scaffolding so you don't have to memorize the
# -c/-f/-R/-B/-n incantation. keepalived calls this on every VRRP
# transition (you wire notify_master/backup/fault to it in keepalived.conf).
#
#   primary : this node just became MASTER — commit the state replicated
#             from the old master into the kernel so in-flight flows keep
#             forwarding, then resync and bulk-send to the peer.
#   backup  : this node became BACKUP — shorten timers and pull a fresh
#             copy of the peer's table.
#   fault   : the sync link or node faulted — flush and shorten timers.
CONNTRACKD=/usr/sbin/conntrackd

case "$1" in
  primary)
    $CONNTRACKD -c    # commit external cache (peer's flows) into the kernel
    $CONNTRACKD -f    # flush internal + external caches
    $CONNTRACKD -R    # resync internal cache from the (now-committed) kernel
    $CONNTRACKD -B    # bulk-send our table to the peer
    ;;
  backup)
    $CONNTRACKD -t    # shorten kernel timers for the committed entries
    $CONNTRACKD -n    # request a full resync from the current master
    ;;
  fault)
    $CONNTRACKD -t
    $CONNTRACKD -f
    ;;
  *)
    echo "usage: $0 {primary|backup|fault}" >&2
    exit 1
    ;;
esac
