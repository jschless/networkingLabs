#!/bin/bash
# PE2 VRF setup — runs before FRR applies its config
# Creates Linux VRF netdevs; FRR then manages routing tables within them.

# VRF-RED (customer A)
ip link add VRF-RED type vrf table 100
ip link set VRF-RED up

# VRF-BLUE (customer B)
ip link add VRF-BLUE type vrf table 200
ip link set VRF-BLUE up

# Re-apply FRR config now that VRF devices exist
vtysh -b
