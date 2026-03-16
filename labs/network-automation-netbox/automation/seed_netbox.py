#!/usr/bin/env python3
import pathlib

import yaml

from netbox_common import api_post, build_clients, ensure_object

ROOT = pathlib.Path("/workspace")
MODEL = yaml.safe_load((ROOT / "netbox_model.yml").read_text())
nb, session, _ = build_clients("lab-seed-token")


site = ensure_object(
    nb.dcim.sites,
    {"slug": MODEL["site"]["slug"]},
    MODEL["site"],
)
tenant = ensure_object(
    nb.tenancy.tenants,
    {"slug": MODEL["tenant"]["slug"]},
    MODEL["tenant"],
)
manufacturer = ensure_object(
    nb.dcim.manufacturers,
    {"slug": MODEL["manufacturer"]["slug"]},
    MODEL["manufacturer"],
)
platform = ensure_object(
    nb.dcim.platforms,
    {"slug": MODEL["platform"]["slug"]},
    {**MODEL["platform"], "manufacturer": manufacturer.id},
)
device_type = ensure_object(
    nb.dcim.device_types,
    {"slug": MODEL["device_type"]["slug"]},
    {**MODEL["device_type"], "manufacturer": manufacturer.id},
)

roles = {}
for role in MODEL["roles"]:
    roles[role["slug"]] = ensure_object(
        nb.dcim.device_roles, {"slug": role["slug"]}, role
    )

racks = {}
for rack in MODEL["racks"]:
    racks[rack["name"]] = ensure_object(
        nb.dcim.racks,
        {"name": rack["name"], "site_id": site.id},
        {"name": rack["name"], "site": site.id, "status": "active"},
    )

tag_ids = []
for tag in MODEL["tags"]:
    tag_obj = ensure_object(
        nb.extras.tags,
        {"slug": tag},
        {"name": tag, "slug": tag},
    )
    tag_ids.append(tag_obj.id)

vlan_group = ensure_object(
    nb.ipam.vlan_groups,
    {"slug": MODEL["vlan_group"]["slug"]},
    {"name": MODEL["vlan_group"]["name"], "slug": MODEL["vlan_group"]["slug"]},
)

vrfs = {}
for vrf in MODEL["vrfs"]:
    vrfs[vrf["name"]] = ensure_object(
        nb.ipam.vrfs,
        {"name": vrf["name"]},
        {"name": vrf["name"], "rd": vrf["rd"], "tenant": tenant.id},
    )

vlans = {}
for vlan in MODEL["vlans"]:
    vlans[vlan["vid"]] = ensure_object(
        nb.ipam.vlans,
        {"vid": vlan["vid"], "group_id": vlan_group.id},
        {
            "vid": vlan["vid"],
            "name": vlan["name"],
            "status": "active",
            "group": vlan_group.id,
            "tenant": tenant.id,
        },
    )

for prefix in MODEL["prefixes"]:
    payload = {
        "prefix": prefix["prefix"],
        "status": "active",
        "description": prefix["description"],
        "site": site.id,
        "tenant": tenant.id,
    }
    if "vrf" in prefix:
        payload["vrf"] = vrfs[prefix["vrf"]].id
    ensure_object(nb.ipam.prefixes, {"prefix": prefix["prefix"]}, payload)

template_text = (ROOT / MODEL["config_template"]["file"]).read_text()
config_template = ensure_object(
    nb.extras.config_templates,
    {"name": MODEL["config_template"]["name"]},
    {
        "name": MODEL["config_template"]["name"],
        "description": MODEL["config_template"]["description"],
        "template_code": template_text,
    },
)

platform.update({"config_template": config_template.id})
for role in roles.values():
    role.update({"config_template": None})

scope_map = {
    "sites": {site.name: site.id},
    "roles": {role.slug: role.id for role in roles.values()},
    "platforms": {platform.slug: platform.id},
}

for context in MODEL["config_contexts"]:
    payload = {
        "name": context["name"],
        "description": context["description"],
        "weight": context["weight"],
        "is_active": True,
        "data": context["data"],
    }
    scopes = context.get("scopes", {})
    for scope_name, values in scopes.items():
        payload[scope_name] = [scope_map[scope_name][value] for value in values]
    ensure_object(nb.extras.config_contexts, {"name": context["name"]}, payload)

devices = {}
interfaces = {}

for device in MODEL["devices"]:
    device_payload = {
        "name": device["name"],
        "status": "active",
        "site": site.id,
        "device_type": device_type.id,
        "role": roles[device["role"]].id,
        "platform": platform.id,
        "tenant": tenant.id,
        "rack": racks[device["rack"]].id,
        "position": device["position"],
        "face": "front",
        "serial": f"{device['name']}-lab",
        "asset_tag": f"asn-{device['asn']}",
    }
    devices[device["name"]] = ensure_object(
        nb.dcim.devices, {"name": device["name"]}, device_payload
    )
    asn_tag = ensure_object(
        nb.extras.tags,
        {"slug": f"asn-{device['asn']}"},
        {"name": f"asn-{device['asn']}", "slug": f"asn-{device['asn']}"},
    )
    devices[device["name"]].update({"tags": tag_ids + [asn_tag.id]})

    mgmt = ensure_object(
        nb.dcim.interfaces,
        {"device_id": devices[device["name"]].id, "name": "Management0"},
        {
            "device": devices[device["name"]].id,
            "name": "Management0",
            "type": "virtual",
            "mgmt_only": True,
            "enabled": True,
        },
    )
    lo0 = ensure_object(
        nb.dcim.interfaces,
        {"device_id": devices[device["name"]].id, "name": "Loopback0"},
        {
            "device": devices[device["name"]].id,
            "name": "Loopback0",
            "type": "virtual",
            "enabled": True,
        },
    )
    interfaces[(device["name"], "Management0")] = mgmt
    interfaces[(device["name"], "Loopback0")] = lo0

    for intf in device["interfaces"]:
        if intf["name"].startswith("Vlan"):
            intf_type = "virtual"
        else:
            intf_type = "1000base-t"
        payload = {
            "device": devices[device["name"]].id,
            "name": intf["name"],
            "type": intf_type,
            "enabled": True,
        }
        if intf["name"].startswith("Ethernet") and intf.get("mode") == "access":
            payload["description"] = f"access vlan {intf['vlan']}"
            payload["mode"] = "access"
            payload["untagged_vlan"] = vlans[intf["vlan"]].id
        elif intf["name"].startswith("Vlan"):
            payload["description"] = f"{intf.get('vrf', '')} service interface".strip()
            payload["vrf"] = vrfs[intf["vrf"]].id
        iface = ensure_object(
            nb.dcim.interfaces,
            {"device_id": devices[device["name"]].id, "name": intf["name"]},
            payload,
        )
        interfaces[(device["name"], intf["name"])] = iface

    for address, ifname in (
        (device["mgmt_ip"], "Management0"),
        (device["loopback"], "Loopback0"),
    ):
        ip = ensure_object(
            nb.ipam.ip_addresses,
            {"address": address},
            {
                "address": address,
                "status": "active",
                "assigned_object_type": "dcim.interface",
                "assigned_object_id": interfaces[(device["name"], ifname)].id,
                "tenant": tenant.id,
            },
        )
        if ifname == "Management0":
            devices[device["name"]].update({"primary_ip4": ip.id})

    for intf in device["interfaces"]:
        if "address" not in intf:
            continue
        payload = {
            "address": intf["address"],
            "status": "active",
            "assigned_object_type": "dcim.interface",
            "assigned_object_id": interfaces[(device["name"], intf["name"])].id,
            "tenant": tenant.id,
        }
        if "vrf" in intf:
            payload["vrf"] = vrfs[intf["vrf"]].id
        ensure_object(nb.ipam.ip_addresses, {"address": intf["address"]}, payload)

for cable in MODEL["cables"]:
    a = interfaces[(cable["a_device"], cable["a_interface"])]
    b = interfaces[(cable["b_device"], cable["b_interface"])]
    existing = nb.dcim.cables.filter(
        termination_a_id=a.id,
        termination_b_id=b.id,
    )
    if list(existing):
        continue
    payload = {
        "a_terminations": [{"object_type": "dcim.interface", "object_id": a.id}],
        "b_terminations": [{"object_type": "dcim.interface", "object_id": b.id}],
        "status": "connected",
        "type": "cat6a",
        "tenant": tenant.id,
    }
    api_post(session, "/api/dcim/cables/", payload)

print(
    "Seeded NetBox with devices, interfaces, IPAM, VLANs, VRFs, cables, "
    "config context, and a native EOS config template."
)
