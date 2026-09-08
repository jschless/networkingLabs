---
title: opnsense-ipsec-nat-t
---

!!! tip "Practice Lab"
    Build native OPNsense 26.1 IKEv2 through a real NAT boundary, prove ESP-in-UDP on port 4500, and isolate an opaque data-path fault.

!!! warning "Runtime"
    This x86-64/KVM lab starts two 3 GiB OPNsense QEMU VMs from a local external base disk. Run it alone, keep management listeners on loopback, and clean up the disposable overlays when finished.

{% include-markdown "../../../labs/opnsense-ipsec-nat-t/README.md" %}
