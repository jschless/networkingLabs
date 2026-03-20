# FortiGate Platform Notes

This repository uses FortiGate in a hybrid model:

- containerlab deploys the surrounding Linux nodes and host bridges
- QEMU/KVM runs the FortiGate VM directly from the FortiGate `qcow2`
- helper scripts attach the FortiGate data interfaces to those host bridges

The FortiGate `qcow2` is extracted from the locally available Docker image:

```bash
docker image ls vrnetlab/vr-fortios:4.7.11
labs/fortigate-firewall-capstone/extract-fortios.sh
```

## Current Lab Coverage

- `fortigate-firewall-capstone`

## Access Model

In this lab, `port1` stays on a QEMU user-mode management network. Data interfaces `port2` through `port6` attach to the containerlab-created host bridges.

The capstone exposes these host ports:

- SSH CLI: `2222 -> 22`
- Web UI HTTP: `8080 -> 80`
- Web UI HTTPS: `8443 -> 443`

Typical workflow:

```bash
sudo labs/fortigate-firewall-capstone/prepare-bridges.sh
./scripts/lab.sh deploy fortigate-firewall-capstone
sudo labs/fortigate-firewall-capstone/start-fgt.sh
ssh -o StrictHostKeyChecking=no -p 2222 admin@127.0.0.1
```

Use the GUI at:

- `http://127.0.0.1:8080`
- `https://127.0.0.1:8443`

## License Caveat

The base image is `vrnetlab/vr-fortios:4.7.11`. FortiGate releases in this range require manual license activation before the firewall feature set is usable, and the `7.4.11` first-boot flow does not align cleanly with vrnetlab bootstrap automation.

That means:

- the topology can still be documented and deployed
- first boot, password change, and licensing are manual
- the learner must complete license activation manually
- automated checks in this repo intentionally do not claim runtime validation for FortiGate labs

## Interface Naming

FortiGate interface names in this lab follow the direct-QEMU model:

- `port1` = management
- `port2` = WAN
- `port3` = CORP
- `port4` = GUEST
- `port5` = DMZ
- `port6` = DB
