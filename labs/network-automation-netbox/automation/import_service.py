#!/usr/bin/env python3
"""Validate and idempotently import the learner-owned BLUE service artifact."""

import argparse
import pathlib
import sys

import yaml

from netbox_common import LabModelError, build_clients, ensure_object
from seed_netbox import ensure_ip


ROOT = pathlib.Path("/workspace")


def load_artifact(path, contract):
    try:
        document = yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as exc:
        raise LabModelError(f"learner service artifact cannot be read: {exc}") from exc
    if not isinstance(document, dict) or set(document) != {"service"}:
        raise LabModelError("artifact must contain exactly one top-level service key")
    service = document["service"]
    if service != contract:
        raise LabModelError(
            "artifact does not exactly satisfy the stated BLUE service contract"
        )
    return service


def unique_named(endpoint, name, label):
    matches = list(endpoint.filter(name=name))
    if len(matches) != 1:
        raise LabModelError(f"{label}: expected exactly one object, found {len(matches)}")
    return matches[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", nargs="?", default=ROOT / "learner-service.yml")
    args = parser.parse_args()
    model = yaml.safe_load((ROOT / "netbox_model.yml").read_text())
    artifact = pathlib.Path(args.artifact)
    try:
        service = load_artifact(artifact, model["service_contract"])
        nb, _, _ = build_clients("network-automation-netbox service import")
        tenant = unique_named(nb.tenancy.tenants, model["tenant"]["name"], "tenant")
        site = unique_named(nb.dcim.sites, model["site"]["name"], "site")
        group = unique_named(
            nb.ipam.vlan_groups, model["vlan_group"]["name"], "VLAN group"
        )
        vrf = ensure_object(
            nb.ipam.vrfs,
            {"name": service["name"]},
            {
                "name": service["name"],
                "rd": service["rd"],
                "tenant": tenant.id,
            },
            f"VRF {service['name']}",
        )
        vlan = ensure_object(
            nb.ipam.vlans,
            {"vid": service["vlan"]["vid"], "group_id": group.id},
            {
                **service["vlan"],
                "status": "active",
                "group": group.id,
                "tenant": tenant.id,
            },
            f"VLAN {service['vlan']['vid']}",
        )
        ensure_object(
            nb.ipam.prefixes,
            {"prefix": service["prefix"], "vrf_id": vrf.id},
            {
                "prefix": service["prefix"],
                "status": "active",
                "description": f"{service['name']} service",
                "site": site.id,
                "tenant": tenant.id,
                "vrf": vrf.id,
            },
            f"{service['name']} prefix",
        )
        for leaf in service["leaves"]:
            device = unique_named(nb.dcim.devices, leaf["device"], leaf["device"])
            access = ensure_object(
                nb.dcim.interfaces,
                {"device_id": device.id, "name": leaf["access_interface"]},
                {
                    "device": device.id,
                    "name": leaf["access_interface"],
                    "type": "1000base-t",
                    "enabled": True,
                    "description": leaf["access_description"],
                    "mtu": 1500,
                    "mode": "access",
                    "untagged_vlan": vlan.id,
                },
                f"{leaf['device']} {leaf['access_interface']}",
            )
            del access
            svi = ensure_object(
                nb.dcim.interfaces,
                {"device_id": device.id, "name": leaf["svi"]},
                {
                    "device": device.id,
                    "name": leaf["svi"],
                    "type": "virtual",
                    "enabled": True,
                    "description": leaf["svi_description"],
                    "mtu": 1500,
                    "vrf": vrf.id,
                },
                f"{leaf['device']} {leaf['svi']}",
            )
            ensure_ip(
                nb,
                leaf["address"],
                svi,
                tenant,
                f"{leaf['device']} {leaf['svi']}",
                vrf.id,
            )
    except LabModelError as exc:
        print(f"SERVICE MODEL ERROR: {exc}", file=sys.stderr)
        return 2
    print(
        "Imported learner service: BLUE VRF, VLAN 10, and deterministic "
        "Ethernet3/Vlan10 intent on both leaves."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
