#!/usr/bin/env python3
"""Smallest cEOS eAPI transaction/partial-push probe for WP-12."""

import base64
import json
import sys
import urllib.error
import urllib.request

USER = "admin"
PASSWORD = "admin"
DEVICES = {"probe1": "172.31.212.11", "probe2": "172.31.212.12"}


def run_cmds(device, commands):
    request_body = json.dumps(
        {
            "jsonrpc": "2.0",
            "method": "runCmds",
            "params": {"version": 1, "cmds": commands, "format": "json"},
            "id": device,
        }
    ).encode()
    request = urllib.request.Request(
        f"http://{DEVICES[device]}/command-api",
        data=request_body,
        headers={
            "Authorization": "Basic "
            + base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode(),
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        payload = json.load(error)
    if "error" in payload:
        raise RuntimeError(payload["error"]["message"])
    return payload["result"]


def description(device):
    result = run_cmds(device, ["show interfaces Ethernet1 description"])[0]
    return result["interfaceDescriptions"]["Ethernet1"]["description"]


def apply_description(device, value, session):
    if description(device) == value:
        return "zero changes"
    run_cmds(
        device,
        [
            "enable",
            f"configure session {session}",
            "interface Ethernet1",
            f"description {value}",
            "commit",
        ],
    )
    return "one semantic change"


def main():
    for device in DEVICES:
        version, interface = run_cmds(
            device, ["show version", "show interfaces Ethernet1"]
        )
        print(
            f"{device}: version={version['version']}; "
            f"structured_state={interface['interfaces']['Ethernet1']['interfaceStatus']}"
        )
        run_cmds(device, ["enable", "copy running-config flash:probe-baseline.cfg"])

    print(
        "probe1 apply:",
        apply_description("probe1", "accepted-before-device2", "partial-probe1"),
    )
    try:
        run_cmds(
            "probe2",
            [
                "enable",
                "configure session stale-capability",
                "interface Ethernet1",
                "ip address 10.999.1.1/30",
                "commit",
            ],
        )
    except RuntimeError as error:
        print(f"probe2 rejected: {error}")
    else:
        raise AssertionError("probe2 unexpectedly accepted invalid capability data")

    split = description("probe1") == "accepted-before-device2" and not description(
        "probe2"
    )
    print(f"partial_push_detected={str(split).lower()}")
    if not split:
        raise AssertionError("partial push was not observable")

    run_cmds("probe1", ["enable", "configure replace flash:probe-baseline.cfg"])
    print(f"rollback_description={description('probe1')!r}")
    if description("probe1"):
        raise AssertionError("configure replace did not restore probe1")

    print(
        "idempotency first:",
        apply_description("probe1", "idempotent-target", "idempotent-first"),
    )
    print(
        "idempotency second:",
        apply_description("probe1", "idempotent-target", "idempotent-second"),
    )
    run_cmds("probe1", ["enable", "configure replace flash:probe-baseline.cfg"])
    print("probe_result=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
