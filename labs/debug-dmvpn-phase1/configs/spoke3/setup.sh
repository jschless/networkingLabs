#!/bin/bash
ip addr add 10.0.0.13/24 dev eth1
ip tunnel add dmvpn0 mode gre local 10.0.0.13 remote 10.0.0.1 dev eth1
ip link set dmvpn0 up
ip addr add 172.16.0.13/24 dev dmvpn0
vtysh -b
