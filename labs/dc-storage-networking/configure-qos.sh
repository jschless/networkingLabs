#!/usr/bin/env bash
set -euo pipefail

docker exec clab-dc-storage-networking-tor1 bash -c '
  tc qdisc replace dev eth1 root handle 1: htb default 20
  tc class replace dev eth1 parent 1: classid 1:1 htb rate 20mbit ceil 20mbit
  tc class replace dev eth1 parent 1:1 classid 1:10 htb rate 15mbit ceil 20mbit prio 0
  tc class replace dev eth1 parent 1:1 classid 1:20 htb rate 5mbit ceil 5mbit prio 7
  tc filter replace dev eth1 protocol ip parent 1: prio 1 u32 \
    match ip dst 10.111.10.10/32 flowid 1:10
'
