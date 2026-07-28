"""Minimal structured EOS eAPI driver with explicit snapshot/replace rollback."""

from __future__ import annotations

import base64
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


class EapiError(RuntimeError):
    """EOS rejected a command or could not be reached."""


def _load_lab_credentials():
    secret_path = Path("/run/secrets/eapi.env")
    values = {}
    for line in secret_path.read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return (
        os.environ.get("EAPI_USER", values.get("EAPI_USER", "")),
        os.environ.get("EAPI_PASSWORD", values.get("EAPI_PASSWORD", "")),
    )


class EapiDevice:
    calls = 0

    def __init__(self, name, address):
        self.name = name
        self.address = address
        self.user, self.password = _load_lab_credentials()
        if not self.user or not self.password:
            raise EapiError("lab eAPI credentials are unavailable")

    def run(self, commands):
        EapiDevice.calls += 1
        body = json.dumps(
            {
                "jsonrpc": "2.0",
                "method": "runCmds",
                "params": {"version": 1, "cmds": commands, "format": "json"},
                "id": self.name,
            }
        ).encode()
        token = base64.b64encode(f"{self.user}:{self.password}".encode()).decode()
        request = urllib.request.Request(
            f"http://{self.address}/command-api",
            data=body,
            headers={
                "Authorization": f"Basic {token}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=8) as response:
                payload = json.load(response)
        except urllib.error.HTTPError as error:
            payload = json.load(error)
        except (OSError, urllib.error.URLError) as error:
            raise EapiError(f"{self.name} eAPI unavailable: {error}") from error
        if "error" in payload:
            raise EapiError(payload["error"]["message"])
        return payload["result"]

    def version(self):
        result = self.run(["show version"])[0]
        return {
            "model": result["modelName"],
            "version": result["version"],
            "architecture": result["architecture"],
        }

    def state(self):
        description_result, route_result, neighbor_result = self.run(
            [
                "show interfaces Loopback0 description",
                "show ip route 203.0.113.12/32",
                "show ip ospf neighbor",
            ]
        )
        description = description_result["interfaceDescriptions"]["Loopback0"][
            "description"
        ]
        routes = (
            route_result.get("vrfs", {})
            .get("default", {})
            .get("routes", {})
        )
        neighbors = neighbor_result.get("vrfs", {}).get("default", {}).get(
            "instList", {}
        )
        neighbor_count = 0
        for instance in neighbors.values():
            neighbor_count += len(instance.get("ospfNeighborEntries", []))
        return {
            "description": description,
            "canary_present": "203.0.113.12/32" in routes,
            "ospf_neighbors": neighbor_count,
        }

    def snapshot(self, filename):
        result = self.run(
            ["enable", f"copy running-config flash:{filename}"]
        )
        messages = result[1].get("messages", [])
        if not any("completed successfully" in message for message in messages):
            raise EapiError(f"{self.name} snapshot did not complete")
        return filename

    def apply(self, commands, session):
        command_list = ["enable", f"configure session {session}", *commands, "commit"]
        try:
            self.run(command_list)
        except EapiError:
            try:
                self.run(["enable", f"configure session {session} abort"])
            except EapiError:
                pass
            raise

    def rollback(self, filename):
        self.run(["enable", f"configure replace flash:{filename}"])
