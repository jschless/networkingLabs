#!/usr/bin/env python3
"""Synthetic, lab-only Modbus/TCP server with deterministic holding registers."""

import argparse
import json
import time
from pathlib import Path

from pymodbus.datastore import (
    ModbusDeviceContext,
    ModbusSequentialDataBlock,
    ModbusServerContext,
)
from pymodbus.constants import ExcCodes
from pymodbus.server import StartTcpServer


class LoggedDataBlock(ModbusSequentialDataBlock):
    def __init__(self, values, event_log, maintenance_flag):
        # ModbusDeviceContext converts protocol address 0 to datastore address 1.
        super().__init__(1, values)
        self.event_log = Path(event_log)
        self.maintenance_flag = Path(maintenance_flag)

    def setValues(self, address, values):
        if not self.maintenance_flag.exists():
            event = {
                "ts": int(time.time()),
                "event": "holding-register-write-denied",
                "address": address,
                "values": list(values),
                "reason": "maintenance-window-closed",
            }
            with self.event_log.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(event, sort_keys=True) + "\n")
            return ExcCodes.DEVICE_BUSY
        super().setValues(address, values)
        event = {
            "ts": int(time.time()),
            "event": "holding-register-write",
            "address": address,
            "values": list(values),
        }
        with self.event_log.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, sort_keys=True) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=502)
    parser.add_argument("--state", required=True)
    parser.add_argument("--event-log", required=True)
    parser.add_argument("--maintenance-flag", required=True)
    args = parser.parse_args()

    state = json.loads(Path(args.state).read_text(encoding="utf-8"))
    values = [state["line_speed_rpm"], state["tank_level_pct"]] + [0] * 98
    block = LoggedDataBlock(values, args.event_log, args.maintenance_flag)
    device = ModbusDeviceContext(hr=block)
    context = ModbusServerContext(devices=device, single=True)
    StartTcpServer(context=context, address=(args.listen, args.port))


if __name__ == "__main__":
    main()
