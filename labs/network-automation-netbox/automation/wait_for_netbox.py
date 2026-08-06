#!/usr/bin/env python3
"""Bounded authenticated NetBox readiness probe."""

import argparse
import sys

from netbox_common import wait_for_authenticated_status


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, default=360)
    parser.add_argument("--interval", type=int, default=5)
    args = parser.parse_args()
    try:
        status = wait_for_authenticated_status(
            args.timeout, args.interval, "network-automation-netbox readiness"
        )
    except TimeoutError as exc:
        print(exc, file=sys.stderr)
        return 1
    version = status.get("netbox-version") or status.get("netbox_version")
    if version != "4.1.11":
        print(f"authenticated NetBox version mismatch: {version!r}", file=sys.stderr)
        return 1
    print("Authenticated NetBox API ready: 4.1.11")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
