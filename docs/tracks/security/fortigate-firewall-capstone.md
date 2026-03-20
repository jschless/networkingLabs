---
title: fortigate-firewall-capstone
---

!!! tip "Capstone Lab"
    Single-device FortiGate firewall policy build with objects, NAT, VIPs, ordering, and logs

!!! note "Images"
    FortiGate base image: `vrnetlab/vr-fortios:4.7.11`

    Support image: `docker build -t fortigate-tools:local labs/fortigate-firewall-capstone/`

!!! warning "Manual License Activation"
    This lab is documented to the repo standard, but it cannot be unattended-validated here because FortiGate first login and licensing must be completed manually. The FortiGate VM runs directly under QEMU/KVM and attaches to containerlab-managed bridges.

{%
  include-markdown "../../../labs/fortigate-firewall-capstone/README.md"
%}
