#!/usr/bin/env python3
"""Runtime-only health-driven DNS publisher for the GSLB assessment ticket."""

from __future__ import annotations

import argparse
import os
import signal
import socket
import time
from pathlib import Path


PROBE_SOURCE = "10.70.53.53"
PROBE_PORT = 8081
SITES = {
    "site_a": {
        "probe": "10.70.41.40",
        "expected": b"cloud-health-a-ok",
        "answers": ("10.70.41.40", "2001:db8:70:41::40"),
    },
    "site_b": {
        "probe": "10.70.42.40",
        "expected": b"cloud-health-b-ok",
        "answers": ("10.70.42.40", "2001:db8:70:42::40"),
    },
}
HOSTNAME = "global.hybrid.test"
HOSTS_PATH = Path("/run/range-t1-gslb-hosts")
STATE_PATH = Path("/run/range-t1-gslb-state.env")
PID_PATH = Path("/run/range-t1-gslb-controller.pid")
DNSMASQ_PID_PATH = Path("/run/range-dnsmasq.pid")


def probe_site(address: str, expected: bytes) -> str:
    request = (
        b"GET / HTTP/1.0\r\n"
        b"Host: global.hybrid.test\r\n"
        b"Connection: close\r\n\r\n"
    )
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1.5)
            sock.bind((PROBE_SOURCE, 0))
            sock.connect((address, PROBE_PORT))
            sock.sendall(request)
            response = b""
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                response += chunk
    except OSError:
        return "down"
    return "healthy" if expected in response else "down"


def current_health() -> dict[str, str]:
    return {
        name: probe_site(str(site["probe"]), bytes(site["expected"]))
        for name, site in SITES.items()
    }


def state_text(health: dict[str, str]) -> str:
    return "\n".join(
        (
            "generation_mode=health-probe",
            f"probe_source={PROBE_SOURCE}",
            f"probe_port={PROBE_PORT}",
            f"site_a_endpoint={SITES['site_a']['probe']}:{PROBE_PORT}",
            f"site_a={health['site_a']}",
            f"site_b_endpoint={SITES['site_b']['probe']}:{PROBE_PORT}",
            f"site_b={health['site_b']}",
            f"checked_epoch={int(time.time())}",
        )
    ) + "\n"


def hosts_text(health: dict[str, str]) -> str:
    lines: list[str] = []
    for name, site in SITES.items():
        if health[name] == "healthy":
            lines.extend(f"{answer} {HOSTNAME}" for answer in site["answers"])
    return "\n".join(lines) + ("\n" if lines else "")


def replace(path: Path, content: str) -> bool:
    if path.exists() and path.read_text() == content:
        return False
    temporary = path.with_suffix(path.suffix + ".new")
    temporary.write_text(content)
    os.replace(temporary, path)
    return True


def signal_dnsmasq() -> None:
    try:
        pid = int(DNSMASQ_PID_PATH.read_text().strip())
        os.kill(pid, signal.SIGHUP)
    except (FileNotFoundError, ProcessLookupError, ValueError):
        pass


def publish_once() -> dict[str, str]:
    health = current_health()
    if replace(HOSTS_PATH, hosts_text(health)):
        signal_dnsmasq()
    replace(STATE_PATH, state_text(health))
    return health


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe-only", action="store_true")
    args = parser.parse_args()

    if args.probe_only:
        print(state_text(current_health()), end="")
        return

    running = True

    def stop(_signum: int, _frame: object) -> None:
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    PID_PATH.write_text(f"{os.getpid()}\n")
    try:
        while running:
            publish_once()
            time.sleep(1)
    finally:
        PID_PATH.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
