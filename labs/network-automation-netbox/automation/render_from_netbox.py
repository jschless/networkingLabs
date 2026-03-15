#!/usr/bin/env python3
import collections
import ipaddress
import os
import pathlib
import sys

import jinja2
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
            "description": "lab-render-token",
        },
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json()["key"]


NETBOX_TOKEN = ensure_token()

nb = pynetbox.api(NETBOX_URL, token=NETBOX_TOKEN)
template = jinja2.Template(
    """hostname {{ device.name }}
!
username admin privilege 15 role network-admin secret admin
!
ip routing
!
{% for vrf in vrfs %}
vrf instance {{ vrf }}
!
{% endfor %}
{% for vlan in vlans %}
vlan {{ vlan.vid }}
   name {{ vlan.name }}
!
{% endfor %}
interface Loopback0
   ip address {{ device.loopback }}
!
{% for iface in device.fabric_interfaces %}
interface {{ iface.name }}
   description to {{ iface.peer_device }} {{ iface.peer_interface }}
   no switchport
   ip address {{ iface.address }}
   no shutdown
!
{% endfor %}
{% for iface in device.access_interfaces %}
interface {{ iface.name }}
   description access port for VLAN {{ iface.vlan }}
   switchport access vlan {{ iface.vlan }}
   no shutdown
!
{% endfor %}
{% for svi in device.svis %}
interface {{ svi.name }}
   description {{ svi.description }}
   vrf {{ svi.vrf }}
   ip address {{ svi.address }}
   no autostate
!
{% endfor %}
router bgp {{ device.asn }}
   router-id {{ device.router_id }}
   maximum-paths 2 ecmp 2
{% for neigh in device.neighbors %}
   neighbor {{ neigh.ip }} remote-as {{ neigh.asn }}
{% endfor %}
   !
   address-family ipv4
{% for neigh in device.neighbors %}
      neighbor {{ neigh.ip }} activate
{% endfor %}
      network {{ device.loopback }}
   !
!
ip name-server 1.1.1.1
ntp server time.google.com
!
management api http-commands
   no shutdown
   protocol http
!
end
"""
)


def get_device_model(name):
    for device in MODEL["devices"]:
        if device["name"] == name:
            return device
    raise KeyError(name)


ip_to_endpoint = {}
for device in MODEL["devices"]:
    for iface in device["interfaces"]:
        if "address" in iface:
            ip_to_endpoint[iface["address"]] = (device["name"], iface["name"])

vlans = MODEL["vlans"]
vrfs = [vrf["name"] for vrf in MODEL["vrfs"]]
outdir = ROOT / "generated"
outdir.mkdir(exist_ok=True)

for device in MODEL["devices"]:
    local = {
        "name": device["name"],
        "asn": device["asn"],
        "loopback": device["loopback"],
        "router_id": str(ipaddress.ip_interface(device["loopback"]).ip),
        "fabric_interfaces": [],
        "access_interfaces": [],
        "svis": [],
        "neighbors": [],
    }
    for iface in device["interfaces"]:
        if iface["name"].startswith("Ethernet") and "address" in iface:
            subnet = ipaddress.ip_interface(iface["address"]).network
            for candidate, endpoint in ip_to_endpoint.items():
                if endpoint[0] == device["name"]:
                    continue
                if ipaddress.ip_interface(candidate).network == subnet:
                    peer_device = get_device_model(endpoint[0])
                    local["fabric_interfaces"].append(
                        {
                            "name": iface["name"],
                            "address": iface["address"],
                            "peer_device": endpoint[0],
                            "peer_interface": endpoint[1],
                        }
                    )
                    local["neighbors"].append(
                        {
                            "ip": str(ipaddress.ip_interface(candidate).ip),
                            "asn": peer_device["asn"],
                        }
                    )
                    break
        elif iface["name"].startswith("Ethernet") and iface.get("mode") == "access":
            local["access_interfaces"].append(
                {"name": iface["name"], "vlan": iface["vlan"]}
            )
        elif iface["name"].startswith("Vlan"):
            local["svis"].append(
                {
                    "name": iface["name"],
                    "address": iface["address"],
                    "vrf": iface["vrf"],
                    "description": f"{iface['vrf']} service gateway",
                }
            )

    rendered = template.render(device=local, vlans=vlans, vrfs=vrfs)
    (outdir / f"{device['name']}.cfg").write_text(rendered)

print(f"Rendered {len(MODEL['devices'])} configs into {outdir}")
