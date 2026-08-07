#!/usr/bin/env python3
"""Load and validate the NetBox fabric relationship graph."""

from collections import defaultdict
import ipaddress
import pathlib

import yaml

from netbox_common import api_get, paginated_results


ROOT = pathlib.Path("/workspace")
MANAGED_NAMES = ("leaf1", "leaf2", "spine1", "spine2")


def nested_id(value):
    if not value:
        return None
    if isinstance(value, dict):
        return value.get("id")
    return value


def nested_name(value):
    if not value:
        return None
    if isinstance(value, dict):
        return value.get("name") or value.get("display")
    return str(value)


def nested_slug(value):
    if not value or not isinstance(value, dict):
        return None
    return value.get("slug")


def nested_value(value):
    if isinstance(value, dict):
        return value.get("value")
    return value


def termination_id(termination):
    return termination.get("object_id") or nested_id(termination.get("object"))


def load_state(session):
    model = yaml.safe_load((ROOT / "netbox_model.yml").read_text())
    devices = paginated_results(session, "/api/dcim/devices/", {"tag": "managed"})
    interfaces = paginated_results(session, "/api/dcim/interfaces/")
    addresses = paginated_results(session, "/api/ipam/ip-addresses/")
    cables = paginated_results(session, "/api/dcim/cables/")
    platforms = paginated_results(session, "/api/dcim/platforms/")
    config_templates = paginated_results(session, "/api/extras/config-templates/")
    vrfs = paginated_results(session, "/api/ipam/vrfs/")
    vlans = paginated_results(session, "/api/ipam/vlans/")
    prefixes = paginated_results(session, "/api/ipam/prefixes/")

    device_by_name = {item["name"]: item for item in devices}
    interface_by_id = {
        item["id"]: item
        for item in interfaces
        if nested_name(item.get("device")) in device_by_name
    }
    interfaces_by_device = defaultdict(list)
    for interface in interface_by_id.values():
        interfaces_by_device[nested_name(interface["device"])].append(interface)

    addresses_by_interface = defaultdict(list)
    for address in addresses:
        assigned = address.get("assigned_object") or {}
        assigned_id = nested_id(assigned) or address.get("assigned_object_id")
        if assigned_id in interface_by_id:
            addresses_by_interface[assigned_id].append(address)

    cables_by_interface = defaultdict(list)
    cable_pairs = []
    for cable in cables:
        a_ids = [termination_id(item) for item in cable.get("a_terminations", [])]
        b_ids = [termination_id(item) for item in cable.get("b_terminations", [])]
        ids = [item for item in a_ids + b_ids if item in interface_by_id]
        for interface_id in ids:
            cables_by_interface[interface_id].append(cable)
        if len(a_ids) == 1 and len(b_ids) == 1:
            cable_pairs.append((a_ids[0], b_ids[0], cable))

    return {
        "model": model,
        "devices": devices,
        "device_by_name": device_by_name,
        "interfaces": interfaces,
        "interface_by_id": interface_by_id,
        "interfaces_by_device": interfaces_by_device,
        "addresses": addresses,
        "addresses_by_interface": addresses_by_interface,
        "cables": cables,
        "cables_by_interface": cables_by_interface,
        "cable_pairs": cable_pairs,
        "platforms": platforms,
        "config_templates": config_templates,
        "vrfs": vrfs,
        "vlans": vlans,
        "prefixes": prefixes,
        "session": session,
    }


def expected_maps(model):
    devices = {item["name"]: item for item in model["devices"]}
    fabric_interfaces = {}
    for device in model["devices"]:
        for interface in device["interfaces"]:
            fabric_interfaces[(device["name"], interface["name"])] = interface
    cable_peers = {}
    for cable in model["cables"]:
        a = (cable["a_device"], cable["a_interface"])
        b = (cable["b_device"], cable["b_interface"])
        cable_peers[a] = b
        cable_peers[b] = a
    return devices, fabric_interfaces, cable_peers


def interface_map(state, device_name):
    return {
        interface["name"]: interface
        for interface in state["interfaces_by_device"].get(device_name, [])
    }


def one_address(state, device_name, interface_name, interface, errors):
    addresses = state["addresses_by_interface"].get(interface["id"], [])
    if len(addresses) != 1:
        errors.append(
            f"{device_name} {interface_name} expected exactly one IPv4 address; "
            f"found {len(addresses)}"
        )
        return None
    try:
        return ipaddress.ip_interface(addresses[0]["address"])
    except ValueError:
        errors.append(
            f"{device_name} {interface_name} has invalid address "
            f"{addresses[0].get('address')!r}"
        )
        return None


def validate_model(state, require_service=True):
    model = state["model"]
    expected_devices, expected_fabric, expected_peers = expected_maps(model)
    errors = []

    actual_names = sorted(item["name"] for item in state["devices"])
    if actual_names != list(MANAGED_NAMES):
        errors.append(
            "fabric managed devices expected leaf1, leaf2, spine1, spine2; found "
            + ", ".join(actual_names or ["none"])
        )

    expected_platform_model = model["platform"]
    expected_platforms = [
        item
        for item in state["platforms"]
        if item.get("name") == expected_platform_model["name"]
        and item.get("slug") == expected_platform_model["slug"]
    ]
    expected_platform = expected_platforms[0] if len(expected_platforms) == 1 else None
    if not expected_platform:
        observed_platforms = sorted(
            f"{item.get('name')!r}/{item.get('slug')!r}"
            for item in state["platforms"]
        )
        errors.append(
            "platform identity must exist exactly once as "
            f"{expected_platform_model['name']!r}/{expected_platform_model['slug']!r}; "
            f"found {observed_platforms or ['none']}"
        )
    else:
        expected_manufacturer = model["manufacturer"]
        actual_manufacturer = expected_platform.get("manufacturer")
        if (
            nested_name(actual_manufacturer) != expected_manufacturer["name"]
            or nested_slug(actual_manufacturer) != expected_manufacturer["slug"]
        ):
            errors.append(
                f"platform {expected_platform_model['name']} manufacturer must be "
                f"{expected_manufacturer['name']!r}/{expected_manufacturer['slug']!r}; "
                f"found {nested_name(actual_manufacturer)!r}/"
                f"{nested_slug(actual_manufacturer)!r}"
            )

    expected_template_model = model["config_template"]
    expected_templates = [
        item
        for item in state["config_templates"]
        if item.get("name") == expected_template_model["name"]
    ]
    expected_template = expected_templates[0] if len(expected_templates) == 1 else None
    if not expected_template:
        observed_templates = sorted(
            item.get("name") or "unnamed" for item in state["config_templates"]
        )
        errors.append(
            "config template identity must exist exactly once as "
            f"{expected_template_model['name']!r}; "
            f"found {observed_templates or ['none']}"
        )
    else:
        if expected_template.get("description") != expected_template_model["description"]:
            errors.append(
                f"config template {expected_template_model['name']} description must be "
                f"{expected_template_model['description']!r}; "
                f"found {expected_template.get('description')!r}"
            )
        try:
            template_detail = api_get(
                state["session"],
                f"/api/extras/config-templates/{expected_template['id']}/",
            )
        except Exception as exc:  # requests reports the precise status downstream
            errors.append(
                f"config template {expected_template_model['name']} body unavailable: {exc}"
            )
        else:
            expected_body = (ROOT / expected_template_model["file"]).read_text()
            actual_body = template_detail.get("template_code")
            if (
                not isinstance(actual_body, str)
                or actual_body.rstrip("\r\n") != expected_body.rstrip("\r\n")
            ):
                errors.append(
                    f"config template {expected_template_model['name']} body must "
                    f"exactly match /workspace/{expected_template_model['file']}"
                )

    if expected_platform:
        expected_template_id = expected_template["id"] if expected_template else None
        actual_template_id = nested_id(expected_platform.get("config_template"))
        if not expected_template_id or actual_template_id != expected_template_id:
            errors.append(
                f"platform {expected_platform_model['name']} config template must "
                f"reference {expected_template_model['name']!r}; found template ID "
                f"{actual_template_id!r}"
            )

    expected_roles = {item["slug"]: item for item in model["roles"]}
    for device_name in sorted(expected_devices):
        device = state["device_by_name"].get(device_name)
        if not device:
            errors.append(f"{device_name} device is missing or lacks managed tag")
            continue
        local_asn = (device.get("custom_fields") or {}).get("local_asn")
        expected_asn = expected_devices[device_name]["local_asn"]
        if not isinstance(local_asn, int) or local_asn != expected_asn:
            errors.append(
                f"{device_name} local_asn must be integer {expected_asn}; found "
                f"{local_asn!r}"
            )
        expected_role = expected_roles[expected_devices[device_name]["role"]]
        actual_role = device.get("role")
        if (
            nested_name(actual_role) != expected_role["name"]
            or nested_slug(actual_role) != expected_role["slug"]
        ):
            errors.append(
                f"{device_name} role must be {expected_role['name']!r}/"
                f"{expected_role['slug']!r}; found {nested_name(actual_role)!r}/"
                f"{nested_slug(actual_role)!r}"
            )
        if not expected_platform or nested_id(device.get("platform")) != expected_platform["id"]:
            actual_platform = device.get("platform")
            errors.append(
                f"{device_name} platform must be {expected_platform_model['name']!r}/"
                f"{expected_platform_model['slug']!r}; found "
                f"{nested_name(actual_platform)!r}/{nested_slug(actual_platform)!r}"
            )
        try:
            device_detail = api_get(
                state["session"], f"/api/dcim/devices/{device['id']}/"
            )
            context = device_detail.get("config_context") or {}
        except Exception as exc:  # requests reports the precise status downstream
            errors.append(f"{device_name} effective config context unavailable: {exc}")
        else:
            maximum_paths = (context.get("bgp") or {}).get("maximum_paths")
            if maximum_paths != 2:
                errors.append(
                    f"{device_name} config context bgp.maximum_paths must be 2; "
                    f"found {maximum_paths!r}"
                )

        by_name = interface_map(state, device_name)
        for required_name in ("Management0", "Loopback0"):
            if required_name not in by_name:
                errors.append(f"{device_name} {required_name} is missing")
        loopback = by_name.get("Loopback0")
        if loopback:
            value = one_address(state, device_name, "Loopback0", loopback, errors)
            expected = ipaddress.ip_interface(expected_devices[device_name]["loopback"])
            if value and value != expected:
                errors.append(
                    f"{device_name} Loopback0 address must be {expected}; found {value}"
                )
        management = by_name.get("Management0")
        if management:
            value = one_address(state, device_name, "Management0", management, errors)
            expected = ipaddress.ip_interface(expected_devices[device_name]["mgmt_ip"])
            if value and value != expected:
                errors.append(
                    f"{device_name} Management0 address must be {expected}; found {value}"
                )
            primary = nested_id(device.get("primary_ip4"))
            management_ips = state["addresses_by_interface"].get(management["id"], [])
            if len(management_ips) == 1 and primary != management_ips[0]["id"]:
                errors.append(
                    f"{device_name} primary IPv4 is not its sole Management0 address"
                )

    endpoint_values = {}
    checked_cable_statuses = set()
    for endpoint, expected_interface in sorted(expected_fabric.items()):
        device_name, interface_name = endpoint
        interface = interface_map(state, device_name).get(interface_name)
        if not interface:
            errors.append(f"{device_name} {interface_name} fabric interface is missing")
            continue
        expected_peer = expected_peers[endpoint]
        expected_description = f"to {expected_peer[0]} {expected_peer[1]}"
        if interface.get("description", "") != expected_description:
            errors.append(
                f"{device_name} {interface_name} description must be "
                f"{expected_description!r}; found {interface.get('description', '')!r}"
            )
        if interface.get("enabled") is not True:
            errors.append(f"{device_name} {interface_name} must be enabled")
        if interface.get("mtu") != expected_interface["mtu"]:
            errors.append(
                f"{device_name} {interface_name} MTU must be "
                f"{expected_interface['mtu']}; found {interface.get('mtu')!r}"
            )
        value = one_address(state, device_name, interface_name, interface, errors)
        if value:
            endpoint_values[endpoint] = value
            expected_value = ipaddress.ip_interface(expected_interface["address"])
            if value != expected_value:
                errors.append(
                    f"{device_name} {interface_name} address must be "
                    f"{expected_value}; found {value}"
                )
        endpoint_cables = state["cables_by_interface"].get(interface["id"], [])
        if len(endpoint_cables) != 1:
            errors.append(
                f"{device_name} {interface_name} expected exactly one connected cable; "
                f"found {len(endpoint_cables)}"
            )
            continue
        cable = endpoint_cables[0]
        if cable["id"] not in checked_cable_statuses:
            checked_cable_statuses.add(cable["id"])
            cable_status = nested_value(cable.get("status"))
            if cable_status != "connected":
                errors.append(
                    f"{device_name} {interface_name} connected cable status must be "
                    f"'connected'; found {cable_status!r}"
                )
        endpoint_ids = [
            termination_id(item)
            for side in ("a_terminations", "b_terminations")
            for item in cable.get(side, [])
        ]
        peer_ids = [item for item in endpoint_ids if item != interface["id"]]
        peer_interface = (
            state["interface_by_id"].get(peer_ids[0]) if len(peer_ids) == 1 else None
        )
        actual_peer = (
            nested_name(peer_interface.get("device")), peer_interface.get("name")
        ) if peer_interface else None
        if actual_peer != expected_peer:
            errors.append(
                f"{device_name} {interface_name} cable peer must be "
                f"{expected_peer[0]} {expected_peer[1]}; found {actual_peer!r}"
            )

    for cable in model["cables"]:
        a = (cable["a_device"], cable["a_interface"])
        b = (cable["b_device"], cable["b_interface"])
        a_value = endpoint_values.get(a)
        b_value = endpoint_values.get(b)
        if not a_value or not b_value:
            continue
        if (
            a_value.network != b_value.network
            or a_value.network.prefixlen != 31
            or {a_value.ip, b_value.ip} != set(a_value.network.hosts())
        ):
            errors.append(
                f"{a[0]} {a[1]} cable to {b[0]} {b[1]} must contain the only "
                f"two endpoints of one /31; found {a_value} and {b_value}"
            )

    scoped_assignments = defaultdict(list)
    for address in state["addresses"]:
        assigned = address.get("assigned_object") or {}
        assigned_id = nested_id(assigned) or address.get("assigned_object_id")
        if assigned_id not in state["interface_by_id"]:
            continue
        key = (address.get("address"), nested_id(address.get("vrf")))
        scoped_assignments[key].append(address["id"])
    for (address, vrf_id), ids in sorted(scoped_assignments.items()):
        if len(ids) > 1:
            errors.append(
                f"fabric address {address} VRF {vrf_id or 'global'} has "
                f"{len(ids)} duplicate assignments"
            )

    if require_service:
        validate_service(state, errors)
    return errors


def validate_service(state, errors):
    service = state["model"]["service_contract"]
    matching_vrfs = [item for item in state["vrfs"] if item["name"] == service["name"]]
    if len(matching_vrfs) != 1 or matching_vrfs[0].get("rd") != service["rd"]:
        errors.append(
            f"service {service['name']} VRF must exist exactly once with RD "
            f"{service['rd']}"
        )
        vrf_id = None
    else:
        vrf_id = matching_vrfs[0]["id"]
    matching_vlans = [
        item for item in state["vlans"] if item["vid"] == service["vlan"]["vid"]
    ]
    if len(matching_vlans) != 1 or matching_vlans[0]["name"] != service["vlan"]["name"]:
        errors.append(
            f"service VLAN {service['vlan']['vid']} must exist exactly once as "
            f"{service['vlan']['name']}"
        )
        vlan_id = None
    else:
        vlan_id = matching_vlans[0]["id"]
    matching_prefixes = [
        item
        for item in state["prefixes"]
        if item["prefix"] == service["prefix"] and nested_id(item.get("vrf")) == vrf_id
    ]
    if vrf_id and len(matching_prefixes) != 1:
        errors.append(
            f"service prefix {service['prefix']} must exist exactly once in VRF "
            f"{service['name']}"
        )

    for leaf in service["leaves"]:
        by_name = interface_map(state, leaf["device"])
        access = by_name.get(leaf["access_interface"])
        svi = by_name.get(leaf["svi"])
        if not access:
            errors.append(
                f"{leaf['device']} {leaf['access_interface']} service access "
                "interface is missing"
            )
        else:
            mode = access.get("mode") or {}
            if mode.get("value") != "access" or nested_id(access.get("untagged_vlan")) != vlan_id:
                errors.append(
                    f"{leaf['device']} {leaf['access_interface']} must be access "
                    f"VLAN {service['vlan']['vid']}"
                )
            if access.get("description", "") != leaf["access_description"]:
                errors.append(
                    f"{leaf['device']} {leaf['access_interface']} description must "
                    f"be {leaf['access_description']!r}"
                )
            if access.get("enabled") is not True or access.get("mtu") != 1500:
                errors.append(
                    f"{leaf['device']} {leaf['access_interface']} must be enabled "
                    "with MTU 1500"
                )
        if not svi:
            errors.append(f"{leaf['device']} {leaf['svi']} service SVI is missing")
        else:
            if svi.get("description", "") != leaf["svi_description"]:
                errors.append(
                    f"{leaf['device']} {leaf['svi']} description must be "
                    f"{leaf['svi_description']!r}"
                )
            if nested_id(svi.get("vrf")) != vrf_id:
                errors.append(
                    f"{leaf['device']} {leaf['svi']} must belong to VRF "
                    f"{service['name']}"
                )
            addresses = state["addresses_by_interface"].get(svi["id"], [])
            matching = [
                item
                for item in addresses
                if item["address"] == leaf["address"]
                and nested_id(item.get("vrf")) == vrf_id
            ]
            if len(addresses) != 1 or len(matching) != 1:
                errors.append(
                    f"{leaf['device']} {leaf['svi']} must have sole address "
                    f"{leaf['address']} in VRF {service['name']}"
                )


def build_render_contexts(state):
    model = state["model"]
    expected_devices, expected_fabric, expected_peers = expected_maps(model)
    contexts = {}
    for device_name in sorted(expected_devices):
        device = state["device_by_name"][device_name]
        by_name = interface_map(state, device_name)
        loopback_record = state["addresses_by_interface"][by_name["Loopback0"]["id"]][0]
        loopback = loopback_record["address"]
        context = {
            "local_asn": device["custom_fields"]["local_asn"],
            "router_id": str(ipaddress.ip_interface(loopback).ip),
            "loopback": {"address": loopback},
            "fabric_interfaces": [],
            "neighbors": [],
            "access_interfaces": [],
            "svis": [],
            "service_vlans": [],
            "service_vrfs": [],
        }
        for endpoint, interface_model in sorted(expected_fabric.items()):
            if endpoint[0] != device_name:
                continue
            interface = by_name[endpoint[1]]
            address = state["addresses_by_interface"][interface["id"]][0]["address"]
            peer = expected_peers[endpoint]
            peer_interface = interface_map(state, peer[0])[peer[1]]
            peer_address = state["addresses_by_interface"][peer_interface["id"]][0]["address"]
            peer_asn = state["device_by_name"][peer[0]]["custom_fields"]["local_asn"]
            context["fabric_interfaces"].append(
                {
                    "name": endpoint[1],
                    "address": address,
                    "description": interface["description"],
                    "mtu": interface_model["mtu"],
                }
            )
            context["neighbors"].append(
                {"ip": str(ipaddress.ip_interface(peer_address).ip), "asn": peer_asn}
            )

        if device_name.startswith("leaf"):
            service = model["service_contract"]
            leaf = next(item for item in service["leaves"] if item["device"] == device_name)
            access = by_name[leaf["access_interface"]]
            svi = by_name[leaf["svi"]]
            context["service_vrfs"] = [{"name": service["name"]}]
            context["service_vlans"] = [service["vlan"]]
            context["access_interfaces"] = [
                {
                    "name": access["name"],
                    "description": access["description"],
                    "vlan": service["vlan"]["vid"],
                    "mtu": access["mtu"],
                }
            ]
            service_address = state["addresses_by_interface"][svi["id"]][0]["address"]
            context["svis"] = [
                {
                    "name": svi["name"],
                    "description": svi["description"],
                    "vrf": service["name"],
                    "address": service_address,
                }
            ]
        contexts[device_name] = context
    return contexts
