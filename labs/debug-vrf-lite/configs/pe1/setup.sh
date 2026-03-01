#!/bin/bash
# PE1 VRF setup

ip link add VRF-RED type vrf table 100
ip link set VRF-RED up

ip link add VRF-BLUE type vrf table 200
ip link set VRF-BLUE up

vtysh -b
