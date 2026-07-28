#!/usr/bin/env python3
"""Run positive and negative service-path probes from the real client node."""

import json
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer


def curl(source):
    result = subprocess.run(
        [
            "curl",
            "-sS",
            "--interface",
            source,
            "--connect-timeout",
            "2",
            "--max-time",
            "4",
            "-o",
            "/tmp/path-body",
            "-w",
            "%{http_code}",
            "http://10.112.20.10:8080/",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    return {"code": result.stdout, "exit": result.returncode}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/verify":
            self.send_error(404)
            return
        payload = {
            "corp": curl("10.112.10.10"),
            "guest": curl("10.112.10.20"),
        }
        body = json.dumps(payload, sort_keys=True).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


HTTPServer(("0.0.0.0", 9090), Handler).serve_forever()
