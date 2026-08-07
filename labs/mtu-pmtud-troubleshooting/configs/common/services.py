#!/usr/bin/env python3
"""Run the shared UDP echo service and optional threaded HTTP service."""

from __future__ import annotations

import argparse
import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HTTP_BODY = b"M" * 262144


def udp_echo() -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(("0.0.0.0", 9999))
        while True:
            data, peer = sock.recvfrom(65535)
            sock.sendto(f"ack:{len(data)}".encode("ascii"), peer)


class ExactBodyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(HTTP_BODY)))
        self.end_headers()
        self.wfile.write(HTTP_BODY)

    def log_message(self, _format: str, *_args: object) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--http", action="store_true")
    args = parser.parse_args()

    thread = threading.Thread(target=udp_echo, name="udp-echo", daemon=True)
    thread.start()

    if args.http:
        ThreadingHTTPServer(("0.0.0.0", 8080), ExactBodyHandler).serve_forever()
    thread.join()


if __name__ == "__main__":
    main()
