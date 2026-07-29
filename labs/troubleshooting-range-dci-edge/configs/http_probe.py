#!/usr/bin/env python3
import argparse
import socket

parser = argparse.ArgumentParser()
parser.add_argument("--expect-denied", action="store_true")
parser.add_argument("host")
parser.add_argument("port", type=int)
parser.add_argument("expected", nargs="?")
args = parser.parse_args()

try:
    with socket.create_connection((args.host, args.port), timeout=2) as connection:
        connection.sendall(b"GET / HTTP/1.0\r\nHost: range.test\r\n\r\n")
        chunks = []
        while True:
            chunk = connection.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
        response = b"".join(chunks).decode(errors="replace")
except OSError:
    if args.expect_denied:
        raise SystemExit(0)
    raise

if args.expect_denied:
    raise SystemExit("request unexpectedly succeeded")
if args.expected and args.expected not in response:
    raise SystemExit(f"expected {args.expected!r} in response")
