#!/usr/bin/env python3
"""Periodic HMI/historian reader for deterministic synthetic process values."""

import json
import subprocess
import sys
import time
from pathlib import Path


def main():
    role = sys.argv[1]
    out = Path(f"/run/ot/{role}.jsonl")
    targets = ("10.110.40.101", "10.110.40.102")
    while True:
        now = int(time.time())
        for target in targets:
            proc = subprocess.run(
                ["/opt/ot/modbus-client", "read", target, "--timeout", "1"],
                capture_output=True, text=True, timeout=3, check=False
            )
            event = {"ts": now, "role": role, "target": target,
                     "ok": proc.returncode == 0}
            if proc.returncode == 0:
                event.update(json.loads(proc.stdout))
            else:
                event["error"] = (proc.stderr or proc.stdout).strip()
            with out.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(event, sort_keys=True) + "\n")
        time.sleep(2)


if __name__ == "__main__":
    main()
