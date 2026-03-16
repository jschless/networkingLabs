#!/usr/bin/env python3
import json
import pathlib
import sys

from netbox_common import build_clients, ensure_object


ROOT = pathlib.Path("/workspace")
FACTS_DIR = ROOT / "facts"


def interface_type(name):
    if name.startswith(("Loopback", "Vlan", "Management")):
        return "virtual"
    return "1000base-t"


if not FACTS_DIR.exists():
    print("Run facts.yml first to populate /workspace/facts", file=sys.stderr)
    sys.exit(1)


nb, _, _ = build_clients("lab-discovery-token")
changes = []

for facts_file in sorted(FACTS_DIR.glob("*.json")):
    facts = json.loads(facts_file.read_text())
    hostname = facts["ansible_net_hostname"]
    device = nb.dcim.devices.get(name=hostname)
    if not device:
        raise RuntimeError(f"{hostname}: device missing in NetBox")

    serial = facts.get("ansible_net_serialnum")
    if serial and device.serial != serial:
        device.update({"serial": serial})
        changes.append(f"{hostname}: updated serial to {serial}")

    for ifname, observed in sorted(facts.get("ansible_net_interfaces", {}).items()):
        payload = {
            "device": device.id,
            "name": ifname,
            "type": interface_type(ifname),
            "enabled": observed.get("operstatus") != "disabled",
            "description": observed.get("description", ""),
            "mtu": observed.get("mtu"),
        }
        mac = observed.get("macaddress")
        if mac:
            payload["mac_address"] = mac

        interface = ensure_object(
            nb.dcim.interfaces,
            {"device_id": device.id, "name": ifname},
            payload,
        )

        ipv4 = observed.get("ipv4")
        if ipv4:
            ensure_object(
                nb.ipam.ip_addresses,
                {"address": f"{ipv4['address']}/{ipv4['masklen']}"},
                {
                    "address": f"{ipv4['address']}/{ipv4['masklen']}",
                    "status": "active",
                    "assigned_object_type": "dcim.interface",
                    "assigned_object_id": interface.id,
                },
            )

        changes.append(f"{hostname}: synced {ifname}")

if not changes:
    print("No discovery changes were needed.")
else:
    print("Discovery sync completed:")
    for change in changes:
        print(f" - {change}")
