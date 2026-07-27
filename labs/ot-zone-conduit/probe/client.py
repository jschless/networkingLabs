#!/usr/bin/env python3
import json
import sys
from pymodbus.client import ModbusTcpClient

mode = sys.argv[1] if len(sys.argv) > 1 else "read"
client = ModbusTcpClient("10.250.20.2", port=502, timeout=2)
if not client.connect():
    raise SystemExit("connection failed")

if mode == "write":
    result = client.write_register(1, 88, device_id=1)
    if result.isError():
        raise SystemExit(f"write failed: {result}")

result = client.read_holding_registers(0, count=2, device_id=1)
if result.isError():
    raise SystemExit(f"read failed: {result}")
print(json.dumps({"line_speed_rpm": result.registers[0],
                  "tank_level_pct": result.registers[1]}))
client.close()
