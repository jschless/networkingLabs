#!/usr/bin/env python3
"""Allowlisted, expiring lab RTBH control endpoint."""

import json
import socket
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PREFIX = "203.0.113.200/32"
TOKEN = "LAB-ONLY-RTBH-CONTROL"
SYSLOG = ("10.114.60.10", 514)
timers: list[threading.Timer] = []


def log(message: str) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.sendto(f"<14>edge rtbh: {message}".encode(), SYSLOG)


def clear() -> None:
    subprocess.run(["ip", "route", "del", "blackhole", PREFIX], check=False)
    log(f"action=clear prefix={PREFIX} reason=expiry")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        if self.headers.get("Authorization") != f"Bearer {TOKEN}":
            self.send_error(403)
            log(f"action=deny source={self.client_address[0]} reason=token")
            return
        length = int(self.headers.get("Content-Length", "0"))
        request = json.loads(self.rfile.read(length) or b"{}")
        if request.get("prefix") != PREFIX or not 2 <= int(request.get("ttl", 0)) <= 10:
            self.send_error(400)
            log(f"action=deny source={self.client_address[0]} reason=scope")
            return
        ttl = int(request["ttl"])
        subprocess.run(["ip", "route", "replace", "blackhole", PREFIX, "metric", "5"], check=True)
        timer = threading.Timer(ttl, clear)
        timer.daemon = True
        timer.start()
        timers.append(timer)
        log(f"action=install source={self.client_address[0]} prefix={PREFIX} ttl={ttl}")
        body = json.dumps({"prefix": PREFIX, "ttl": ttl, "status": "installed"}) + "\n"
        self.send_response(202)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, fmt: str, *args: object) -> None:
        return


ThreadingHTTPServer(("0.0.0.0", 9000), Handler).serve_forever()
