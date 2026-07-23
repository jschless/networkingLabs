#!/bin/sh
ip addr add 172.17.10.10/24 dev eth1
ip link set eth1 up
ip route replace default via 172.17.10.1 dev eth1
