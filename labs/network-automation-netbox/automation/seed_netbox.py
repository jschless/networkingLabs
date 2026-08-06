#!/usr/bin/env python3
"""Idempotently seed the underlay/DCIM baseline, but no learner service."""

import pathlib

import yaml

from netbox_common import (
    LabModelError,
    api_patch,
    api_post,
    build_clients,
    ensure_object,
    paginated_results,
)


ROOT = pathlib.Path("/workspace")


def object_id(value):
    if value is None:
        return None
    if isinstance(value, dict):
        return value.get("id")
    return getattr(value, "id", value)


def scoped_ip(nb, address, vrf_id, label):
    matches = []
    for candidate in nb.ipam.ip_addresses.filter(address=address):
        if object_id(candidate.vrf) == vrf_id:
            matches.append(candidate)
    if len(matches) > 1:
        raise LabModelError(
            f"{label}: duplicate {address} assignments in VRF {vrf_id or 'global'}"
        )
    return matches[0] if matches else None


def ensure_ip(nb, address, interface, tenant, label, vrf_id=None):
    payload = {
        "address": address,
        "status": "active",
        "assigned_object_type": "dcim.interface",
        "assigned_object_id": interface.id,
        "tenant": tenant.id,
        "vrf": vrf_id,
    }
    ip_address = scoped_ip(nb, address, vrf_id, label)
    if ip_address:
        ip_address.update(payload)
        return nb.ipam.ip_addresses.get(id=ip_address.id) or ip_address
    return nb.ipam.ip_addresses.create(payload)


def cable_endpoint_id(termination):
    return termination.get("object_id") or (termination.get("object") or {}).get("id")


def ensure_cable(session, interfaces, cable):
    a = interfaces[(cable["a_device"], cable["a_interface"])]
    b = interfaces[(cable["b_device"], cable["b_interface"])]
    cables = paginated_results(session, "/api/dcim/cables/")
    desired = frozenset((a.id, b.id))
    for existing in cables:
        endpoint_ids = {
            cable_endpoint_id(item)
            for side in ("a_terminations", "b_terminations")
            for item in existing.get(side, [])
        }
        if endpoint_ids == desired:
            api_patch(
                session,
                f"/api/dcim/cables/{existing['id']}/",
                {"status": "connected", "type": "cat6a"},
            )
            return
        if a.id in endpoint_ids or b.id in endpoint_ids:
            raise LabModelError(
                f"{cable['a_device']}:{cable['a_interface']} to "
                f"{cable['b_device']}:{cable['b_interface']}: endpoint already "
                "belongs to a different cable"
            )
    api_post(
        session,
        "/api/dcim/cables/",
        {
            "a_terminations": [
                {"object_type": "dcim.interface", "object_id": a.id}
            ],
            "b_terminations": [
                {"object_type": "dcim.interface", "object_id": b.id}
            ],
            "status": "connected",
            "type": "cat6a",
        },
    )


def main():
    model = yaml.safe_load((ROOT / "netbox_model.yml").read_text())
    nb, session, _ = build_clients("network-automation-netbox seed")

    site = ensure_object(nb.dcim.sites, {"slug": model["site"]["slug"]}, model["site"])
    tenant = ensure_object(
        nb.tenancy.tenants, {"slug": model["tenant"]["slug"]}, model["tenant"]
    )
    manufacturer = ensure_object(
        nb.dcim.manufacturers,
        {"slug": model["manufacturer"]["slug"]},
        model["manufacturer"],
    )
    platform = ensure_object(
        nb.dcim.platforms,
        {"slug": model["platform"]["slug"]},
        {**model["platform"], "manufacturer": manufacturer.id},
    )
    device_type = ensure_object(
        nb.dcim.device_types,
        {"slug": model["device_type"]["slug"]},
        {**model["device_type"], "manufacturer": manufacturer.id},
    )
    roles = {
        role["slug"]: ensure_object(
            nb.dcim.device_roles, {"slug": role["slug"]}, role
        )
        for role in model["roles"]
    }
    racks = {
        rack["name"]: ensure_object(
            nb.dcim.racks,
            {"name": rack["name"], "site_id": site.id},
            {"name": rack["name"], "site": site.id, "status": "active"},
        )
        for rack in model["racks"]
    }
    tags = [
        ensure_object(
            nb.extras.tags,
            {"slug": tag},
            {"name": tag, "slug": tag},
        )
        for tag in model["tags"]
    ]
    custom_field = model["custom_field"]
    ensure_object(
        nb.extras.custom_fields,
        {"name": custom_field["name"]},
        custom_field,
        "custom field local_asn",
    )
    vlan_group = model["vlan_group"]
    ensure_object(
        nb.ipam.vlan_groups,
        {"slug": vlan_group["slug"]},
        vlan_group,
    )

    for prefix in model["prefixes"]:
        ensure_object(
            nb.ipam.prefixes,
            {"prefix": prefix["prefix"], "vrf_id": "null"},
            {
                **prefix,
                "status": "active",
                "site": site.id,
                "tenant": tenant.id,
            },
            f"global prefix {prefix['prefix']}",
        )

    template_model = model["config_template"]
    template = ensure_object(
        nb.extras.config_templates,
        {"name": template_model["name"]},
        {
            "name": template_model["name"],
            "description": template_model["description"],
            "template_code": (ROOT / template_model["file"]).read_text(),
        },
    )
    platform.update({"config_template": template.id})
    for role in roles.values():
        role.update({"config_template": None})

    scope_map = {"sites": {site.name: site.id}}
    for context in model["config_contexts"]:
        payload = {
            "name": context["name"],
            "description": context["description"],
            "weight": context["weight"],
            "is_active": True,
            "data": context["data"],
        }
        for scope_name, values in context.get("scopes", {}).items():
            payload[scope_name] = [scope_map[scope_name][value] for value in values]
        ensure_object(nb.extras.config_contexts, {"name": context["name"]}, payload)

    peer_by_endpoint = {}
    for cable in model["cables"]:
        a = (cable["a_device"], cable["a_interface"])
        b = (cable["b_device"], cable["b_interface"])
        peer_by_endpoint[a] = b
        peer_by_endpoint[b] = a

    devices = {}
    interfaces = {}
    for device_model in model["devices"]:
        name = device_model["name"]
        device = ensure_object(
            nb.dcim.devices,
            {"name": name},
            {
                "name": name,
                "status": "active",
                "site": site.id,
                "device_type": device_type.id,
                "role": roles[device_model["role"]].id,
                "platform": platform.id,
                "tenant": tenant.id,
                "rack": racks[device_model["rack"]].id,
                "position": device_model["position"],
                "face": "front",
                "asset_tag": None,
                "custom_fields": {"local_asn": device_model["local_asn"]},
                "tags": [tag.id for tag in tags],
            },
            f"device {name}",
        )
        devices[name] = device

        interface_models = [
            {
                "name": "Management0",
                "type": "virtual",
                "mgmt_only": True,
                "enabled": True,
                "description": "",
                "mtu": 1500,
            },
            {
                "name": "Loopback0",
                "type": "virtual",
                "enabled": True,
                "description": "fabric router-id",
                "mtu": 65535,
            },
        ]
        for interface_model in device_model["interfaces"]:
            peer = peer_by_endpoint[(name, interface_model["name"])]
            interface_models.append(
                {
                    "name": interface_model["name"],
                    "type": "1000base-t",
                    "enabled": True,
                    "description": f"to {peer[0]} {peer[1]}",
                    "mtu": interface_model["mtu"],
                }
            )
        for interface_model in interface_models:
            interface = ensure_object(
                nb.dcim.interfaces,
                {"device_id": device.id, "name": interface_model["name"]},
                {"device": device.id, **interface_model},
                f"{name} {interface_model['name']}",
            )
            interfaces[(name, interface_model["name"])] = interface

        management_ip = ensure_ip(
            nb,
            device_model["mgmt_ip"],
            interfaces[(name, "Management0")],
            tenant,
            f"{name} Management0",
        )
        device.update({"primary_ip4": management_ip.id})
        ensure_ip(
            nb,
            device_model["loopback"],
            interfaces[(name, "Loopback0")],
            tenant,
            f"{name} Loopback0",
        )
        for interface_model in device_model["interfaces"]:
            ensure_ip(
                nb,
                interface_model["address"],
                interfaces[(name, interface_model["name"])],
                tenant,
                f"{name} {interface_model['name']}",
            )

    for cable in model["cables"]:
        ensure_cable(session, interfaces, cable)

    print(
        "Seeded the idempotent underlay/DCIM baseline: 4 devices, 16 interfaces, "
        "16 addresses, 4 cables, local_asn, template, and context."
    )


if __name__ == "__main__":
    main()
