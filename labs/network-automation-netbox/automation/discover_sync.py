#!/usr/bin/env python3
"""Adopt observation-owned serials without changing intent-owned fields."""

import argparse
import json
import pathlib
import sys

from netbox_common import LabModelError, build_clients, get_unique


ROOT = pathlib.Path("/workspace")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--facts-dir", type=pathlib.Path, default=ROOT / "facts")
    args = parser.parse_args()
    if not args.facts_dir.is_dir():
        print(f"facts directory is missing: {args.facts_dir}", file=sys.stderr)
        return 2

    nb, _, _ = build_clients("network-automation-netbox serial adoption")
    facts_files = sorted(args.facts_dir.glob("*.json"))
    if len(facts_files) != 4:
        print(f"expected four fact files, found {len(facts_files)}", file=sys.stderr)
        return 2

    try:
        for facts_file in facts_files:
            facts = json.loads(facts_file.read_text())
            hostname = facts["ansible_net_hostname"]
            device = get_unique(
                nb.dcim.devices, f"device {hostname}", {"name": hostname}
            )
            if not device:
                raise LabModelError(f"{hostname}: device missing in NetBox")
            serial = facts.get("ansible_net_serialnum")
            if not serial:
                raise LabModelError(f"{hostname}: observed serial is empty")
            if device.serial != serial:
                device.update({"serial": serial})
                print(f"OBSERVATION ADOPTED: {hostname} serial")
            else:
                print(f"OBSERVATION UNCHANGED: {hostname} serial")
            print(
                f"INTENT PRESERVED: {hostname} interfaces, descriptions, admin "
                "state, MTU, VRFs, VLANs, and addresses"
            )
    except (KeyError, json.JSONDecodeError, LabModelError) as exc:
        print(f"DISCOVERY ERROR: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
