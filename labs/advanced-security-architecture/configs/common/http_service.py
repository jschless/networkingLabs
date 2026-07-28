#!/usr/bin/env python3
"""Small deterministic HTTP service used only for safe lab traffic."""

import json
import os
import socket
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROLE = os.environ.get("LAB_ROLE", "service")
PORT = int(os.environ.get("LAB_PORT", "8080"))
SYSLOG = os.environ.get("LAB_SYSLOG", "")


def emit(message: str) -> None:
    if not SYSLOG:
        return
    host, port = SYSLOG.rsplit(":", 1)
    stamp = datetime.now(timezone.utc).isoformat()
    payload = f"<14>{stamp} {socket.gethostname()} {ROLE}: {message}"
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.sendto(payload.encode(), (host, int(port)))


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        event_id = self.headers.get("X-Lab-Event", "none")
        allowed = {
            "protected-app": {"/", "/public-app", "/partner-app", "/internal-app", "/ids-alert", "/ids-block"},
            "internet-test": {"/", "/approved", "/attack-target"},
            "management": {"/healthz"},
        }.get(ROLE, {"/"})
        path = self.path.split("?", 1)[0]
        status = 200 if path in allowed else 404
        body = json.dumps({"role": ROLE, "path": path, "event_id": event_id}) + "\n"
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Origin-Role", ROLE)
        self.end_headers()
        self.wfile.write(body.encode())
        emit(f"event={event_id} action=http status={status} path={path} source={self.client_address[0]}")

    def log_message(self, fmt: str, *args: object) -> None:
        return


ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
