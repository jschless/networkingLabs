# OPNsense platform notes

The OPNsense labs run an external QEMU/KVM VM beside ContainerLab. They require
a Linux x86-64 host with `/dev/kvm`; OPNsense itself is x86-64-only. The VM is
open-source and has no license activation step, but its disk is intentionally
not committed to this repository.

## One-time base image

Download an OPNsense x86-64 image from the official project and install it in
QEMU. Allocate at least 3 GB RAM and one virtio management NIC. During this
one-time setup:

1. Assign the first NIC (`vtnet0`) to the management network and configure it
   for DHCP.
2. Set the lab `root` password to `opnsense`, then enable SSH password login
   for `root` on that interface.
3. Enable the HTTPS web UI on that interface.
4. Leave data NICs unassigned: individual labs attach those as `vtnet1+`.
5. Shut down and convert/copy the installed disk into the shared location:

```bash
sudo scripts/opnsense/prepare-base-image.sh /path/to/installed-opnsense.qcow2
```

The default location is `/var/lib/containerlab/opnsense/opnsense-base.qcow2`.
Set `OPNSENSE_BASE_IMAGE` to use a different location.

Each lab creates a throwaway overlay, so its `reset` helper restores this
baseline without reinstalling the firewall. QEMU/KVM and `/dev/kvm` are
required. Run one OPNsense lab at a time; the NAT-T lab starts two 3 GB VMs.

## Lab lifecycle

For an OPNsense lab, deploy its ContainerLab side first, then start its VM:

```bash
sudo labs/<lab>/prepare-bridges.sh
./scripts/lab.sh deploy <lab>
sudo labs/<lab>/start-opnsense.sh
```

Open the printed GUI URL or serial console. Stop and reset the VM with the
lab's `stop-opnsense.sh` / `reset-opnsense.sh` helpers before destroying the
ContainerLab topology.

## Management access

The prepared lab image uses the same credentials for the HTTPS web UI and
SSH:

| Field | Value |
|---|---|
| Username | `root` |
| Password | `opnsense` |

These are intentionally simple lab credentials. The QEMU runtime binds its
management ports to `127.0.0.1` on the lab machine, so they are not directly
reachable from another computer.

To open a lab UI remotely, create an SSH tunnel from the other computer. For
example, to reach a UI listening on port `8444` on the lab machine:

```bash
ssh -N -L 8444:127.0.0.1:8444 <lab-host-user>@<lab-host-ip>
```

Keep the SSH session open and browse to `https://127.0.0.1:8444` on the other
computer. Substitute the GUI port printed by the lab's start helper. A browser
warning for the self-signed OPNsense certificate is expected. Prefer this SSH
tunnel over changing the QEMU listener to `0.0.0.0`.
