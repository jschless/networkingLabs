#!/usr/bin/env python3
import ipaddress
import pathlib
from netbox_common import api_post, build_clients, paginated_results


ROOT = pathlib.Path("/workspace")
OUTDIR = ROOT / "generated"
OUTDIR.mkdir(exist_ok=True)


def parse_asn(device):
    asset_tag = device.get("asset_tag", "")
    if asset_tag.startswith("asn-"):
        return int(asset_tag.split("-", 1)[1])

    for tag in device.get("tags", []):
        slug = tag.get("slug", "")
        if slug.startswith("asn-"):
            return int(slug.split("-", 1)[1])

    raise ValueError(f"Unable to infer ASN for {device['name']}")


def interface_type(name):
    if name.startswith(("Loopback", "Vlan", "Management")):
        return "virtual"
    return "1000base-t"


def build_inventory(session):
    devices = paginated_results(session, "/api/dcim/devices/", {"tag": "managed"})
    device_by_name = {device["name"]: device for device in devices}
    interfaces = {}
    ips = {}

    for device in devices:
        device_interfaces = paginated_results(
            session, "/api/dcim/interfaces/", {"device_id": device["id"]}
        )
        device_ips = paginated_results(
            session, "/api/ipam/ip-addresses/", {"device": device["name"]}
        )
        interfaces[device["name"]] = device_interfaces
        ips[device["name"]] = {}
        for address in device_ips:
            assigned = address.get("assigned_object")
            if not assigned:
                continue
            ips[device["name"]][assigned["name"]] = {
                "address": address["address"],
                "vrf": address.get("vrf", {}),
            }

    return devices, device_by_name, interfaces, ips


def build_render_contexts(device_by_name, interfaces, ips):
    subnet_index = {}
    for device_name, device_interfaces in interfaces.items():
        for iface in device_interfaces:
            address = ips[device_name].get(iface["name"], {}).get("address")
            if not address:
                continue
            subnet = str(ipaddress.ip_interface(address).network)
            subnet_index.setdefault(subnet, []).append(
                {
                    "device": device_name,
                    "interface": iface["name"],
                    "address": address,
                }
            )

    contexts = {}
    for device_name, device_interfaces in interfaces.items():
        local_asn = parse_asn(device_by_name[device_name])
        loopback = ips[device_name]["Loopback0"]
        context = {
            "local_asn": local_asn,
            "router_id": str(ipaddress.ip_interface(loopback["address"]).ip),
            "loopback": loopback,
            "fabric_interfaces": [],
            "access_interfaces": [],
            "svis": [],
            "neighbors": [],
            "service_vlans": [],
            "service_vrfs": [],
        }

        for iface in device_interfaces:
            name = iface["name"]
            address = ips[device_name].get(name, {}).get("address")
            if name.startswith("Ethernet") and address:
                subnet = str(ipaddress.ip_interface(address).network)
                peers = [
                    peer for peer in subnet_index[subnet] if peer["device"] != device_name
                ]
                if not peers:
                    continue
                peer = peers[0]
                peer_device = device_by_name[peer["device"]]
                context["fabric_interfaces"].append(
                    {
                        "name": name,
                        "address": address,
                        "peer_device": peer["device"],
                        "peer_interface": peer["interface"],
                    }
                )
                context["neighbors"].append(
                    {
                        "ip": str(ipaddress.ip_interface(peer["address"]).ip),
                        "asn": parse_asn(peer_device),
                    }
                )
            elif name.startswith("Ethernet") and iface.get("mode", {}).get("value") == "access":
                vlan = iface.get("untagged_vlan") or {}
                context["access_interfaces"].append(
                    {
                        "name": name,
                        "vlan": vlan.get("vid"),
                    }
                )
            elif name.startswith("Vlan") and address:
                vrf = iface.get("vrf") or ips[device_name].get(name, {}).get("vrf") or {}
                context["svis"].append(
                    {
                        "name": name,
                        "address": address,
                        "vrf": vrf.get("name"),
                        "description": iface.get("description") or f"{vrf.get('name', '')} service gateway".strip(),
                    }
                )

        context["service_vlans"] = sorted(
            [
                {"vid": item["vlan"], "name": next(
                    iface["untagged_vlan"]["name"]
                    for iface in device_interfaces
                    if iface["name"] == item["name"] and iface.get("untagged_vlan")
                )}
                for item in context["access_interfaces"]
                if item["vlan"] is not None
            ],
            key=lambda item: item["vid"],
        )
        context["service_vrfs"] = sorted(
            [{"name": svi["vrf"]} for svi in context["svis"] if svi["vrf"]],
            key=lambda item: item["name"],
        )
        contexts[device_name] = context

    return contexts


_, session, _ = build_clients("lab-render-token")
devices, device_by_name, interfaces, ips = build_inventory(session)
render_contexts = build_render_contexts(device_by_name, interfaces, ips)

for device in devices:
    rendered = api_post(
        session,
        f"/api/dcim/devices/{device['id']}/render-config/",
        render_contexts[device["name"]],
        accept="text/plain",
    )
    (OUTDIR / f"{device['name']}.cfg").write_text(rendered)

print(f"Rendered {len(devices)} configs from NetBox into {OUTDIR}")
