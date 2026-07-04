#!/bin/bash
set -e
ip link set eth1 up
# Docker manages /etc/resolv.conf as a bind mount, so udhcpc's default
# script fails to update it ("mv: Resource busy") and the learned DNS
# server would never land. Rewrite in place instead of renaming.
sed -i 's|mv -f "$RESOLV_CONF.$$" "$RESOLV_CONF"|cat "$RESOLV_CONF.$$" > "$RESOLV_CONF" \&\& rm -f "$RESOLV_CONF.$$"|' \
    /usr/share/udhcpc/default.script
echo "[client1] Ready for DHCP on eth1"
