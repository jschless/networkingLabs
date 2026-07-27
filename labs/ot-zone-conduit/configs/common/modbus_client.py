#!/usr/bin/env python3
"""Small PyModbus CLI used by the HMI, historian, engineering, and checks."""

import argparse
import json
import time

from pymodbus.client import ModbusTcpClient


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("read", "write"))
    parser.add_argument("host")
    parser.add_argument("--address", type=int, default=0)
    parser.add_argument("--count", type=int, default=2)
    parser.add_argument("--value", type=int)
    parser.add_argument("--timeout", type=float, default=2)
    args = parser.parse_args()

    client = ModbusTcpClient(args.host, port=502, timeout=args.timeout)
    if not client.connect():
        raise SystemExit("connection failed")
    if args.operation == "write":
        if args.value is None:
            raise SystemExit("--value is required for write")
        result = client.write_register(
            args.address, args.value, device_id=1
        )
        if result.isError():
            raise SystemExit(f"write denied: {result}")
        payload = {"ts": int(time.time()), "operation": "write",
                   "host": args.host, "address": args.address,
                   "value": args.value}
    else:
        result = client.read_holding_registers(
            args.address, count=args.count, device_id=1
        )
        if result.isError():
            raise SystemExit(f"read failed: {result}")
        payload = {"ts": int(time.time()), "operation": "read",
                   "host": args.host, "address": args.address,
                   "values": result.registers}
    print(json.dumps(payload, sort_keys=True))
    client.close()


if __name__ == "__main__":
    main()
