#!/usr/bin/env bash
set -euxo pipefail

ip addr replace 10.111.10.20/24 dev eth1
ip addr replace 10.111.20.20/24 dev eth2
ip addr replace 10.111.30.20/24 dev eth3
ip link set eth1 mtu 9000
ip link set eth2 mtu 9000
ip link set eth3 mtu 1500
pgrep -x dbus-daemon >/dev/null || /usr/bin/dbus-daemon --system --fork
/usr/lib/systemd/systemd-udevd --daemon || true
modprobe target_core_file
modprobe iscsi_target_mod
truncate -s 128M /var/lib/storage/lun.img
targetcli /iscsi delete iqn.2026-07.lab.example:dc-storage >/dev/null 2>&1 || true
targetcli /backstores/fileio delete storage-lun >/dev/null 2>&1 || true
targetcli /backstores/fileio create storage-lun /var/lib/storage/lun.img 128M write_back=false
targetcli /iscsi create iqn.2026-07.lab.example:dc-storage
targetcli /iscsi/iqn.2026-07.lab.example:dc-storage/tpg1/luns create /backstores/fileio/storage-lun
targetcli /iscsi/iqn.2026-07.lab.example:dc-storage/tpg1 set attribute generate_node_acls=1
targetcli /iscsi/iqn.2026-07.lab.example:dc-storage/tpg1 set attribute authentication=0
targetcli /iscsi/iqn.2026-07.lab.example:dc-storage/tpg1/portals delete 0.0.0.0 3260
targetcli /iscsi/iqn.2026-07.lab.example:dc-storage/tpg1/portals create 10.111.10.20 3260
targetcli /iscsi/iqn.2026-07.lab.example:dc-storage/tpg1/portals create 10.111.20.20 3260
