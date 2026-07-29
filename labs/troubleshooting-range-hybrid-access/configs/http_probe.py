#!/usr/bin/env python3
import argparse
import socket
import sys


parser = argparse.ArgumentParser()
parser.add_argument("host")
parser.add_argument("port", type=int)
parser.add_argument("expected", nargs="?")
parser.add_argument("headers", nargs="*")
parser.add_argument("--expect-denied", action="store_true")
args = parser.parse_args()

request_headers = [b"GET / HTTP/1.0", b"Host: hybrid.test"]
for header in args.headers:
    name, value = header.split("=", 1)
    request_headers.append(f"{name}: {value}".encode())
request = b"\r\n".join(request_headers) + b"\r\n\r\n"

try:
    with socket.create_connection((args.host, args.port), 3) as sock:
        sock.sendall(request)
        response = b""
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            response += chunk
except OSError as exc:
    if args.expect_denied:
        print(f"DENIED {args.host}:{args.port} ({exc.__class__.__name__})")
        sys.exit(0)
    raise

if args.expect_denied:
    print(f"ERROR: {args.host}:{args.port} was reachable", file=sys.stderr)
    sys.exit(1)
if args.expected is None or args.expected.encode() not in response:
    print(response.decode(errors="replace"), file=sys.stderr)
    sys.exit(1)
print(f"PASS {args.host}:{args.port} contains {args.expected}")
