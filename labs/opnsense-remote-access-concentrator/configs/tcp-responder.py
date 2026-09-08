#!/usr/bin/env python3
"""Small deterministic TCP responder for incidental lab service roles."""

import socketserver
import sys


class ReusableThreadingServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


class ResponseHandler(socketserver.BaseRequestHandler):
    def handle(self) -> None:
        self.request.sendall((RESPONSE + "\n").encode("ascii"))


if len(sys.argv) != 3 or not sys.argv[1].isdigit():
    raise SystemExit("usage: tcp-responder.py PORT RESPONSE")

PORT = int(sys.argv[1])
RESPONSE = sys.argv[2]
with ReusableThreadingServer(("0.0.0.0", PORT), ResponseHandler) as server:
    server.serve_forever()
