#!/usr/bin/env python3
import json
import pathlib
import sys
import yaml


ROOT = pathlib.Path("/workspace")
MODEL = yaml.safe_load((ROOT / "netbox_model.yml").read_text())
facts_dir = ROOT / "facts"

if not facts_dir.exists():
    print("Run facts.yml first to populate /workspace/facts", file=sys.stderr)
    sys.exit(1)


def expected_interfaces(device):
    data = {
        "Loopback0": device["loopback"],
        "Management0": device["mgmt_ip"],
    }
    for iface in device["interfaces"]:
        if "address" in iface:
            data[iface["name"]] = iface["address"]
    return data


def observed_interface_address(observed):
    ipv4 = observed.get("ipv4")
    if not ipv4:
        return None
    return f"{ipv4['address']}/{ipv4['masklen']}"


failures = []
for device in MODEL["devices"]:
    facts_file = facts_dir / f"{device['name']}.json"
    if not facts_file.exists():
        failures.append(f"{device['name']}: missing facts file")
        continue
    facts = json.loads(facts_file.read_text())
    interfaces = facts.get("ansible_net_interfaces", {})
    expected = expected_interfaces(device)
    for ifname, address in expected.items():
        observed = interfaces.get(ifname, {})
        observed_addr = observed_interface_address(observed)
        if address != observed_addr:
            failures.append(
                f"{device['name']} {ifname}: expected {address}, observed {observed_addr or 'none'}"
            )

if failures:
    print("Drift detected:")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print("No interface/IP drift detected against the NetBox model.")
