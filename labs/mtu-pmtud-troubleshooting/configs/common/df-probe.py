#!/usr/bin/env python3
"""Send one connected DF UDP datagram and report a stable result."""

from __future__ import annotations

import argparse
import errno
import socket
import sys


def remote_default() -> str:
    """Choose the endpoint opposite this container."""
    return "192.168.1.10" if socket.gethostname().endswith("host-b") else "192.168.2.10"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("payload", type=int)
    parser.add_argument("destination", nargs="?", default=remote_default())
    args = parser.parse_args()

    if not 0 <= args.payload <= 65507:
        parser.error("payload must be between 0 and 65507 bytes")

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(3)
        sock.setsockopt(
            socket.IPPROTO_IP,
            getattr(socket, "IP_MTU_DISCOVER", 10),
            getattr(socket, "IP_PMTUDISC_DO", 2),
        )
        sock.connect((args.destination, 9999))
        try:
            sock.send(b"x" * args.payload)
            reply = sock.recv(4096).decode("ascii", errors="replace")
        except OSError as exc:
            if exc.errno == errno.EMSGSIZE:
                print(f"EMSGSIZE payload={args.payload} destination={args.destination}")
                return 2
            if isinstance(exc, TimeoutError) or exc.errno in {errno.EAGAIN, errno.EWOULDBLOCK}:
                print(f"TIMEOUT payload={args.payload} destination={args.destination}")
                return 3
            print(f"ERROR errno={exc.errno} payload={args.payload} destination={args.destination}")
            return 4

    expected = f"ack:{args.payload}"
    if reply != expected:
        print(f"BAD_REPLY expected={expected} received={reply}")
        return 5
    print(reply)
    return 0


if __name__ == "__main__":
    sys.exit(main())
