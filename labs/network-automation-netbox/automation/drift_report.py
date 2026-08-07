#!/usr/bin/env python3
"""One-to-many-safe intended-versus-observed reconciliation report."""

from collections import defaultdict
import argparse
import json
import pathlib
import sys

from netbox_common import build_clients, paginated_results


ROOT = pathlib.Path("/workspace")
MANAGED_PATTERN = ("Management", "Loopback", "Ethernet", "Vlan")


def nested_name(value):
    if not value:
        return None
    return value.get("name") or value.get("display")


def observed_address(interface):
    ipv4 = interface.get("ipv4")
    if not ipv4:
        return None
    return f"{ipv4['address']}/{ipv4['masklen']}"


def configured_interfaces(facts):
    """Merge operational facts with resource-parsed configured interfaces."""
    observed = {
        name: dict(values)
        for name, values in facts.get("ansible_net_interfaces", {}).items()
    }
    resources = facts.get("ansible_network_resources", {})
    for interface in resources.get("interfaces", []):
        entry = observed.setdefault(interface["name"], {})
        entry["description"] = interface.get("description", "")
        if "mtu" in interface:
            entry["mtu"] = interface["mtu"]
    for interface in resources.get("l3_interfaces", []):
        entry = observed.setdefault(interface["name"], {})
        ipv4 = interface.get("ipv4", [])
        if len(ipv4) == 1 and ipv4[0].get("address"):
            address, masklen = ipv4[0]["address"].rsplit("/", 1)
            entry["ipv4"] = {"address": address, "masklen": int(masklen)}
        elif not ipv4:
            entry.pop("ipv4", None)
    return observed


def report(code, message, diagnostics):
    diagnostics.append(f"[{code}] {message}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--facts-dir", type=pathlib.Path, default=ROOT / "facts")
    args = parser.parse_args()
    if not args.facts_dir.is_dir():
        print(f"facts directory is missing: {args.facts_dir}", file=sys.stderr)
        return 2
    facts_by_device = {}
    for path in sorted(args.facts_dir.glob("*.json")):
        try:
            facts = json.loads(path.read_text())
            facts_by_device[facts["ansible_net_hostname"]] = facts
        except (KeyError, json.JSONDecodeError) as exc:
            print(f"invalid facts file {path}: {exc}", file=sys.stderr)
            return 2

    _, session, _ = build_clients("network-automation-netbox drift report")
    devices = paginated_results(session, "/api/dcim/devices/", {"tag": "managed"})
    netbox_interfaces = paginated_results(session, "/api/dcim/interfaces/")
    addresses = paginated_results(session, "/api/ipam/ip-addresses/")
    device_by_id = {device["id"]: device for device in devices}
    interfaces_by_device = defaultdict(list)
    interface_by_id = {}
    for interface in netbox_interfaces:
        device = interface.get("device") or {}
        if device.get("id") not in device_by_id:
            continue
        interfaces_by_device[nested_name(device)].append(interface)
        interface_by_id[interface["id"]] = interface
    addresses_by_interface = defaultdict(list)
    for address in addresses:
        assigned = address.get("assigned_object") or {}
        if assigned.get("id") in interface_by_id:
            addresses_by_interface[assigned["id"]].append(address["address"])

    diagnostics = []
    expected_names = {device["name"] for device in devices}
    for missing in sorted(expected_names - set(facts_by_device)):
        report("OBSERVATION_MISSING_FACTS", f"{missing}: no fresh facts", diagnostics)
    for extra in sorted(set(facts_by_device) - expected_names):
        report("OBSERVATION_EXTRA_DEVICE", f"{extra}: not managed by NetBox", diagnostics)

    for device in sorted(devices, key=lambda item: item["name"]):
        hostname = device["name"]
        facts = facts_by_device.get(hostname)
        if not facts:
            continue
        observed_serial = facts.get("ansible_net_serialnum")
        intended_serial = device.get("serial") or ""
        if not intended_serial and observed_serial:
            report(
                "OBSERVATION_UNADOPTED_SERIAL",
                f"{hostname}: observed serial {observed_serial!r} is not adopted",
                diagnostics,
            )
        elif intended_serial != observed_serial:
            report(
                "OBSERVATION_SERIAL_MISMATCH",
                f"{hostname}: NetBox serial {intended_serial!r}, observed "
                f"{observed_serial!r}",
                diagnostics,
            )

        intended_lists = defaultdict(list)
        for interface in interfaces_by_device[hostname]:
            intended_lists[interface["name"]].append(interface)
        observed_interfaces = configured_interfaces(facts)
        for ifname, entries in sorted(intended_lists.items()):
            if len(entries) > 1:
                report(
                    "INTENT_MULTIPLE_INTERFACES",
                    f"{hostname} {ifname}: NetBox has {len(entries)} objects",
                    diagnostics,
                )
                continue
            intended = entries[0]
            observed = observed_interfaces.get(ifname)
            if observed is None:
                report(
                    "INTENT_MISSING_LIVE_INTERFACE",
                    f"{hostname} {ifname}: modeled in NetBox, absent from facts",
                    diagnostics,
                )
                continue
            intended_description = intended.get("description") or ""
            observed_description = observed.get("description") or ""
            if intended_description != observed_description:
                report(
                    "INTENT_DESCRIPTION_DRIFT",
                    f"{hostname} {ifname}: NetBox {intended_description!r}, "
                    f"observed {observed_description!r}",
                    diagnostics,
                )
            intended_mtu = intended.get("mtu")
            observed_mtu = observed.get("mtu")
            if intended_mtu is not None and observed_mtu != intended_mtu:
                report(
                    "INTENT_MTU_DRIFT",
                    f"{hostname} {ifname}: NetBox {intended_mtu}, observed "
                    f"{observed_mtu!r}",
                    diagnostics,
                )
            intended_addresses = sorted(addresses_by_interface[intended["id"]])
            live_address = observed_address(observed)
            if len(intended_addresses) > 1:
                report(
                    "INTENT_MULTIPLE_ADDRESSES",
                    f"{hostname} {ifname}: NetBox has {intended_addresses}",
                    diagnostics,
                )
            elif intended_addresses and live_address is None:
                report(
                    "INTENT_MISSING_LIVE_ADDRESS",
                    f"{hostname} {ifname}: NetBox has {intended_addresses[0]}, "
                    "observed none",
                    diagnostics,
                )
            elif not intended_addresses and live_address:
                report(
                    "OBSERVATION_EXTRA_ADDRESS",
                    f"{hostname} {ifname}: observed {live_address}, NetBox has none",
                    diagnostics,
                )
            elif intended_addresses and intended_addresses[0] != live_address:
                report(
                    "INTENT_ADDRESS_DRIFT",
                    f"{hostname} {ifname}: NetBox {intended_addresses[0]}, "
                    f"observed {live_address}",
                    diagnostics,
                )

        for ifname in sorted(observed_interfaces):
            if not ifname.startswith(MANAGED_PATTERN):
                continue
            if ifname not in intended_lists:
                report(
                    "OBSERVATION_EXTRA_INTERFACE",
                    f"{hostname} {ifname}: present in facts, absent from NetBox",
                    diagnostics,
                )

    if diagnostics:
        print("DRIFT DETECTED:")
        for diagnostic in sorted(diagnostics):
            print(f" - {diagnostic}")
        return 1
    print(
        "CLEAN: intent-owned interfaces/addresses/descriptions/MTUs match facts; "
        "observation-owned serials are adopted."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
