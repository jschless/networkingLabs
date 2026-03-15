#!/usr/bin/env python3
import ipaddress
import os
import pathlib
import sys

import pynetbox
import requests
import yaml


ROOT = pathlib.Path("/workspace")
MODEL = yaml.safe_load((ROOT / "netbox_model.yml").read_text())
NETBOX_URL = os.environ.get("NETBOX_URL", "http://172.31.40.23:8080")
NETBOX_TOKEN = os.environ.get("NETBOX_TOKEN")
NETBOX_USERNAME = os.environ.get("NETBOX_USERNAME", "admin")
NETBOX_PASSWORD = os.environ.get("NETBOX_PASSWORD", "admin")


def ensure_token():
    if NETBOX_TOKEN:
        return NETBOX_TOKEN
    resp = requests.post(
        f"{NETBOX_URL}/api/users/tokens/provision/",
        json={
            "username": NETBOX_USERNAME,
            "password": NETBOX_PASSWORD,
            "write_enabled": True,
            "description": "lab-seed-token",
        },
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json()["key"]


NETBOX_TOKEN = ensure_token()

nb = pynetbox.api(NETBOX_URL, token=NETBOX_TOKEN)
session = requests.Session()
session.headers.update(
    {
        "Authorization": f"Token {NETBOX_TOKEN}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
)


def get_or_create(endpoint, lookup, payload):
    obj = endpoint.get(**lookup)
    if obj:
        return obj
    return endpoint.create(payload)


site = get_or_create(
    nb.dcim.sites,
    {"slug": MODEL["site"]["slug"]},
    MODEL["site"],
)
tenant = get_or_create(
    nb.tenancy.tenants,
    {"slug": MODEL["tenant"]["slug"]},
    MODEL["tenant"],
)
manufacturer = get_or_create(
    nb.dcim.manufacturers,
    {"slug": MODEL["manufacturer"]["slug"]},
    MODEL["manufacturer"],
)
platform = get_or_create(
    nb.dcim.platforms,
    {"slug": MODEL["platform"]["slug"]},
    MODEL["platform"],
)
device_type = get_or_create(
    nb.dcim.device_types,
    {"slug": MODEL["device_type"]["slug"]},
    {**MODEL["device_type"], "manufacturer": manufacturer.id},
)

roles = {}
for role in MODEL["roles"]:
    roles[role["slug"]] = get_or_create(
        nb.dcim.device_roles, {"slug": role["slug"]}, role
    )

racks = {}
for rack in MODEL["racks"]:
    racks[rack["name"]] = get_or_create(
        nb.dcim.racks,
        {"name": rack["name"], "site_id": site.id},
        {"name": rack["name"], "site": site.id, "status": "active"},
    )

tag_ids = []
for tag in MODEL["tags"]:
    tag_obj = get_or_create(
        nb.extras.tags,
        {"slug": tag},
        {"name": tag, "slug": tag},
    )
    tag_ids.append(tag_obj.id)

vlan_group = get_or_create(
    nb.ipam.vlan_groups,
    {"slug": MODEL["vlan_group"]["slug"]},
    {"name": MODEL["vlan_group"]["name"], "slug": MODEL["vlan_group"]["slug"]},
)

vrfs = {}
for vrf in MODEL["vrfs"]:
    vrfs[vrf["name"]] = get_or_create(
        nb.ipam.vrfs,
        {"name": vrf["name"]},
        {"name": vrf["name"], "rd": vrf["rd"], "tenant": tenant.id},
    )

vlans = {}
for vlan in MODEL["vlans"]:
    vlans[vlan["vid"]] = get_or_create(
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
    get_or_create(nb.ipam.prefixes, {"prefix": prefix["prefix"]}, payload)

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
    devices[device["name"]] = get_or_create(
        nb.dcim.devices, {"name": device["name"]}, device_payload
    )
    asn_tag = get_or_create(
        nb.extras.tags,
        {"slug": f"asn-{device['asn']}"},
        {"name": f"asn-{device['asn']}", "slug": f"asn-{device['asn']}"},
    )
    devices[device["name"]].update({"tags": tag_ids + [asn_tag.id]})

    mgmt = get_or_create(
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
    lo0 = get_or_create(
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
        if intf["name"].startswith("Ethernet") and "mode" in intf:
            payload["description"] = f"access vlan {intf['vlan']}"
        elif intf["name"].startswith("Vlan"):
            payload["description"] = f"{intf.get('vrf', '')} service interface".strip()
        iface = get_or_create(
            nb.dcim.interfaces,
            {"device_id": devices[device["name"]].id, "name": intf["name"]},
            payload,
        )
        interfaces[(device["name"], intf["name"])] = iface

    for address, ifname in (
        (device["mgmt_ip"], "Management0"),
        (device["loopback"], "Loopback0"),
    ):
        ip = get_or_create(
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
        get_or_create(nb.ipam.ip_addresses, {"address": intf["address"]}, payload)

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
    resp = session.post(f"{NETBOX_URL}/api/dcim/cables/", json=payload, timeout=20)
    resp.raise_for_status()

print("Seeded NetBox with devices, interfaces, IPAM, VLANs, VRFs, and cables.")
