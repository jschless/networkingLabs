#!/usr/bin/env bash
set -euo pipefail

P="clab-dc-storage-networking"
docker exec "$P-initiator1" vm-exec sudo iscsiadm -m session -P 1
docker exec "$P-initiator1" vm-exec sudo multipath -ll
docker exec "$P-initiator1" vm-exec sudo lsblk -S -o NAME,VENDOR,MODEL,SERIAL,TRAN
docker exec "$P-tor1" ip -s link show br-storage-a
docker exec "$P-tor1" tc -s class show dev eth1
docker exec "$P-target1" targetcli /iscsi/iqn.2026-07.lab.example:dc-storage/tpg1/acls ls
