#!/bin/bash
ip tunnel add tun0 mode gre local 203.0.113.6 remote 192.168.1.1 ttl 255
ip link set tun0 up
ip addr add 172.16.0.2/30 dev tun0
vtysh -b
