# FortiGate Platform Notes

This repository uses FortiGate through containerlab's `fortinet_fortigate` kind and the vrnetlab-based image:

```bash
docker image ls vrnetlab/vr-fortios:4.7.11
```

## Current Lab Coverage

- `fortigate-firewall-capstone`

## Access Model

Containerlab reserves `port1` for FortiGate management. Data interfaces start at `port2`.

The capstone exposes these host ports:

- SSH CLI: `2222 -> 22`
- Web UI HTTP: `8080 -> 80`
- Web UI HTTPS: `8443 -> 443`

Typical workflow:

```bash
ssh -o StrictHostKeyChecking=no -p 2222 admin@127.0.0.1
```

Use the GUI at:

- `http://127.0.0.1:8080`
- `https://127.0.0.1:8443`

## License Caveat

The locally available image is `vrnetlab/vr-fortios:4.7.11`. FortiGate releases in this range require manual license activation before the firewall feature set is usable.

That means:

- the topology can still be documented and deployed
- the learner must complete license activation manually
- automated checks in this repo intentionally do not claim runtime validation for FortiGate labs

## Interface Naming

FortiGate interface names in containerlab follow the platform naming model:

- `port1` = management
- `port2` = first data interface
- `port3+` = subsequent data interfaces
