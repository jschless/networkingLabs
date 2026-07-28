#!/usr/bin/env bash
set -euo pipefail

IQN="iqn.2026-07.lab.example:dc-storage"
INITIATOR="iqn.2026-07.lab.example:initiator1"
TPG="/iscsi/$IQN/tpg1"

ip addr replace 10.111.10.20/24 dev eth1
ip addr add 10.111.40.20/24 dev eth1
ip addr replace 10.111.20.20/24 dev eth2
ip addr replace 10.111.30.20/24 dev eth3
ip link set eth1 mtu 1500
ip link set eth2 mtu 1500
ip link set eth3 mtu 1500
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up

pgrep -x dbus-daemon >/dev/null || dbus-daemon --system --fork
/usr/lib/systemd/systemd-udevd --daemon || true
modprobe target_core_file
modprobe iscsi_target_mod

truncate -s 256M /var/lib/storage/lun.img
targetcli /iscsi delete "$IQN" >/dev/null 2>&1 || true
targetcli /backstores/fileio delete storage-lun >/dev/null 2>&1 || true
targetcli /backstores/fileio create storage-lun /var/lib/storage/lun.img 256M write_back=false
targetcli /iscsi create "$IQN"
targetcli "$TPG/luns" create /backstores/fileio/storage-lun
targetcli "$TPG" set attribute generate_node_acls=0
targetcli "$TPG" set attribute authentication=1
targetcli "$TPG" set attribute demo_mode_write_protect=0
targetcli "$TPG/acls" create "$INITIATOR"
targetcli "$TPG/acls/$INITIATOR" set auth \
  userid=labinitiator password=LAB-Storage-26! >/dev/null
targetcli "$TPG/portals" delete 0.0.0.0 3260
targetcli "$TPG/portals" create 10.111.10.20 3260
targetcli "$TPG/portals" create 10.111.20.20 3260
iperf3 -s -D
printf 'READY\n' >/run/storage-target-ready
