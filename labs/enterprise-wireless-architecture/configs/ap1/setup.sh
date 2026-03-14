#!/bin/bash
set -e

ip link set eth1 up
ip link set eth2 up
ip link set eth3 up

ip link add link eth1 name eth1.99 type vlan id 99
ip link add link eth1 name eth1.110 type vlan id 110
ip link add link eth1 name eth1.120 type vlan id 120
ip link set eth1.99 up
ip link set eth1.110 up
ip link set eth1.120 up

ip addr add 192.168.99.30/24 dev eth1.99
ip route replace default via 192.168.99.1

ip link add br-corp type bridge
ip link add br-guest type bridge
ip link set br-corp up
ip link set br-guest up
ip link set eth2 master br-corp
ip link set eth1.110 master br-corp
ip link set eth3 master br-guest
ip link set eth1.120 master br-guest

curl -s http://192.168.99.10:8080 >/dev/null 2>&1 || true

echo "[ap1] simulated AP ready: mgmt VLAN 99, corp SSID VLAN 110, guest SSID VLAN 120"
