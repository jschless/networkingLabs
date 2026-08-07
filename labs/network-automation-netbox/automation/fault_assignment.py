#!/usr/bin/env python3
"""Narrow fault-contract mutation for one NetBox address object."""

import argparse
import sys

from model_graph import load_state, nested_id
from netbox_common import LabModelError, api_patch, build_clients


GOOD = "10.0.0.1/31"
BAD = "10.0.0.9/31"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("break", "repair"))
    args = parser.parse_args()
    _, session, _ = build_clients("network-automation-netbox fault contract")
    state = load_state(session)
    interface = next(
        (
            item
            for item in state["interfaces_by_device"].get("leaf1", [])
            if item["name"] == "Ethernet1"
        ),
        None,
    )
    if not interface:
        raise LabModelError("leaf1 Ethernet1 is absent")
    assignments = state["addresses_by_interface"].get(interface["id"], [])
    if len(assignments) != 1:
        raise LabModelError(
            f"leaf1 Ethernet1 expected one assignment, found {len(assignments)}"
        )
    current = assignments[0]
    allowed = {GOOD, BAD}
    if current["address"] not in allowed or nested_id(current.get("vrf")) is not None:
        raise LabModelError(
            "leaf1 Ethernet1 does not match the narrow fault-contract precondition"
        )
    desired = BAD if args.action == "break" else GOOD
    if current["address"] != desired:
        api_patch(session, f"/api/ipam/ip-addresses/{current['id']}/", {"address": desired})
    verify = load_state(session)
    verify_interface = next(
        item
        for item in verify["interfaces_by_device"]["leaf1"]
        if item["name"] == "Ethernet1"
    )
    values = verify["addresses_by_interface"].get(verify_interface["id"], [])
    if len(values) != 1 or values[0]["address"] != desired:
        print("fault-contract postcondition failed", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except LabModelError as exc:
        print(f"fault-contract refused: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
