#!/bin/sh
ip addr add 172.17.10.20/24 dev eth1
ip addr add 172.17.20.10/24 dev eth2
ip link set eth1 up
ip link set eth2 up
ip route replace default via 172.17.10.1 dev eth1
