#!/usr/bin/env python3
"""Read-only, named assertions for the dedicated NetBox data set."""

import argparse
from model_graph import (
    load_state,
    nested_id,
    validate_model,
    validate_service,
)
from netbox_common import api_get, build_clients, paginated_results


def emit(ok, key, label, detail=""):
    clean_detail = str(detail).replace("\t", " ").replace("\n", "; ")
    print("\t".join(("PASS" if ok else "FAIL", key, label, clean_detail)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=("baseline", "complete"), default="complete")
    args = parser.parse_args()
    _, session, _ = build_clients("network-automation-netbox audit")
    status = api_get(session, "/api/status/")
    version = status.get("netbox-version") or status.get("netbox_version")
    emit(version == "4.1.11", "api", "authenticated NetBox API is version 4.1.11", version)

    state = load_state(session)
    expected_counts = {
        "baseline": {
            "devices": 4,
            "interfaces": 16,
            "addresses": 16,
            "cables": 4,
            "vrfs": 0,
            "vlans": 0,
            "prefixes": 6,
        },
        "complete": {
            "devices": 4,
            "interfaces": 20,
            "addresses": 18,
            "cables": 4,
            "vrfs": 1,
            "vlans": 1,
            "prefixes": 7,
        },
    }[args.phase]
    actual_counts = {
        "devices": len(state["devices"]),
        "interfaces": len(state["interface_by_id"]),
        "addresses": sum(len(items) for items in state["addresses_by_interface"].values()),
        "cables": len(state["cables"]),
        "vrfs": len(state["vrfs"]),
        "vlans": len(state["vlans"]),
        "prefixes": len(state["prefixes"]),
    }
    emit(
        actual_counts == expected_counts,
        "counts",
        f"{args.phase} DCIM/IPAM object counts are exact",
        f"expected={expected_counts} observed={actual_counts}",
    )

    supporting_counts = {
        "sites": len(paginated_results(session, "/api/dcim/sites/")),
        "tenants": len(paginated_results(session, "/api/tenancy/tenants/")),
        "manufacturers": len(paginated_results(session, "/api/dcim/manufacturers/")),
        "platforms": len(state["platforms"]),
        "device_types": len(paginated_results(session, "/api/dcim/device-types/")),
        "roles": len(paginated_results(session, "/api/dcim/device-roles/")),
        "racks": len(paginated_results(session, "/api/dcim/racks/")),
        "tags": len(paginated_results(session, "/api/extras/tags/")),
        "vlan_groups": len(paginated_results(session, "/api/ipam/vlan-groups/")),
        "templates": len(paginated_results(session, "/api/extras/config-templates/")),
        "contexts": len(paginated_results(session, "/api/extras/config-contexts/")),
        "custom_fields": len(paginated_results(session, "/api/extras/custom-fields/")),
    }
    expected_supporting = {
        "sites": 1,
        "tenants": 1,
        "manufacturers": 1,
        "platforms": 1,
        "device_types": 1,
        "roles": 2,
        "racks": 2,
        "tags": 4,
        "vlan_groups": 1,
        "templates": 1,
        "contexts": 1,
        "custom_fields": 1,
    }
    emit(
        supporting_counts == expected_supporting,
        "supporting",
        "supporting DCIM/template/context/custom-field counts are exact",
        f"expected={expected_supporting} observed={supporting_counts}",
    )

    errors = validate_model(state, require_service=False)
    address_errors = [
        item
        for item in errors
        if " address must be " in item or "expected exactly one IPv4 address" in item
    ]
    subnet_errors = [item for item in errors if "only two endpoints of one /31" in item]
    cable_errors = [
        item
        for item in errors
        if ("connected cable" in item or "cable peer must be" in item)
        and item not in subnet_errors
    ]
    categorized = set(address_errors + subnet_errors + cable_errors)
    core_errors = [item for item in errors if item not in categorized]
    emit(
        not core_errors,
        "core",
        "managed devices have local_asn, primary IP, template, and context",
        "; ".join(core_errors),
    )
    emit(
        not cable_errors and len(state["cables"]) == 4,
        "cables",
        "four fabric cables have the exact endpoint relationships",
        "; ".join(cable_errors),
    )
    emit(
        not address_errors,
        "addresses",
        "intended management, loopback, and fabric addresses contain no stale assignments",
        "; ".join(address_errors),
    )
    emit(
        not subnet_errors,
        "subnets",
        "each cabled fabric pair is the sole two-host set of one /31",
        "; ".join(subnet_errors),
    )

    duplicate_keys = []
    seen = {}
    for address in state["addresses"]:
        assigned = address.get("assigned_object") or {}
        assigned_id = nested_id(assigned) or address.get("assigned_object_id")
        if assigned_id not in state["interface_by_id"]:
            continue
        key = (address["address"], nested_id(address.get("vrf")))
        if key in seen:
            duplicate_keys.append(key)
        seen[key] = address["id"]
    emit(
        not duplicate_keys,
        "duplicates",
        "managed interface addresses are unique within each VRF",
        duplicate_keys,
    )

    if args.phase == "complete":
        service_errors = []
        validate_service(state, service_errors)
        emit(
            not service_errors,
            "service",
            "BLUE VRF/VLAN/access/SVI service intent is complete",
            "; ".join(service_errors),
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
