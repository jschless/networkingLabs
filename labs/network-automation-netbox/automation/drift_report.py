#!/usr/bin/env python3
import json
import pathlib
import sys

from netbox_common import build_clients, paginated_results


ROOT = pathlib.Path("/workspace")
facts_dir = ROOT / "facts"

if not facts_dir.exists():
    print("Run facts.yml first to populate /workspace/facts", file=sys.stderr)
    sys.exit(1)

_, session, _ = build_clients("lab-drift-token")


def netbox_device_state(hostname):
    devices = paginated_results(session, "/api/dcim/devices/", {"name": hostname})
    if not devices:
        raise RuntimeError(f"{hostname}: device missing in NetBox")
    device = devices[0]
    interfaces = paginated_results(session, "/api/dcim/interfaces/", {"device": hostname})
    addresses = paginated_results(session, "/api/ipam/ip-addresses/", {"device": hostname})
    ip_by_interface = {}
    for address in addresses:
        assigned = address.get("assigned_object")
        if not assigned:
            continue
        ip_by_interface[assigned["name"]] = address["address"]
    return device, interfaces, ip_by_interface


def observed_interface_address(observed):
    ipv4 = observed.get("ipv4")
    if not ipv4:
        return None
    return f"{ipv4['address']}/{ipv4['masklen']}"


failures = []
for facts_file in sorted(facts_dir.glob("*.json")):
    if not facts_file.exists():
        continue
    facts = json.loads(facts_file.read_text())
    hostname = facts["ansible_net_hostname"]
    device, interfaces, ip_by_interface = netbox_device_state(hostname)
    interfaces = facts.get("ansible_net_interfaces", {})
    if facts.get("ansible_net_serialnum") and device.get("serial") != facts["ansible_net_serialnum"]:
        failures.append(
            f"{hostname}: expected serial {device.get('serial')}, observed {facts['ansible_net_serialnum']}"
        )
    for ifname, address in ip_by_interface.items():
        observed = interfaces.get(ifname, {})
        observed_addr = observed_interface_address(observed)
        if address != observed_addr:
            failures.append(
                f"{hostname} {ifname}: NetBox has {address}, observed {observed_addr or 'none'}"
            )
    netbox_interfaces = {item["name"]: item for item in paginated_results(session, "/api/dcim/interfaces/", {"device": hostname})}
    for ifname, observed in interfaces.items():
        netbox_interface = netbox_interfaces.get(ifname)
        if not netbox_interface:
            failures.append(f"{hostname} {ifname}: present on device, missing in NetBox")
            continue
        observed_desc = observed.get("description", "")
        if observed_desc != netbox_interface.get("description", ""):
            failures.append(
                f"{hostname} {ifname}: NetBox description '{netbox_interface.get('description', '')}' "
                f"observed '{observed_desc}'"
            )

if failures:
    print("Drift detected:")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print("No device/interface drift detected between NetBox and live facts.")
