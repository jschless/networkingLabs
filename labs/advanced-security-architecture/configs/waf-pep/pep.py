#!/usr/bin/env python3
"""Resource PEP consuming a pre-issued lab JWT; identity issuance is out of scope."""

import base64
import hashlib
import hmac
import json
import socket
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

KEY = b"LAB-ONLY-ADVANCED-SECURITY-KEY"
POLICY = Path("/run/asa/partner-policy.json")
SYSLOG = ("10.114.60.10", 514)


def decode(segment: str) -> bytes:
    return base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))


def validate(token: str) -> dict:
    header, payload, signature = token.split(".")
    expected = hmac.new(KEY, f"{header}.{payload}".encode(), hashlib.sha256).digest()
    if not hmac.compare_digest(expected, decode(signature)):
        raise ValueError("signature")
    claims = json.loads(decode(payload))
    if claims.get("exp", 0) < time.time() or claims.get("group") != "partner":
        raise ValueError("claims")
    return claims


def emit(message: str) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.sendto(f"<14>waf-pep pep: {message}".encode(), SYSLOG)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        event_id = self.headers.get("X-Lab-Event", "none")
        try:
            token = self.headers.get("Authorization", "").removeprefix("Bearer ")
            claims = validate(token)
            policy = json.loads(POLICY.read_text())
            if self.path.split("?", 1)[0] not in policy.get(claims["group"], []):
                raise PermissionError("resource")
        except (OSError, ValueError, KeyError, json.JSONDecodeError, PermissionError):
            emit(f"event={event_id} decision=deny source={self.client_address[0]} resource={self.path}")
            self.send_error(403)
            return

        request = urllib.request.Request(
            "http://127.0.0.1:8080/partner-app",
            headers={"X-Lab-Event": event_id, "X-Partner-Subject": claims["sub"]},
        )
        try:
            with urllib.request.urlopen(request, timeout=3) as response:
                body = response.read()
                self.send_response(response.status)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(body)
                emit(f"event={event_id} decision=permit subject={claims['sub']} resource={self.path}")
        except urllib.error.HTTPError as error:
            self.send_error(error.code)

    def log_message(self, fmt: str, *args: object) -> None:
        return


ThreadingHTTPServer(("0.0.0.0", 8443), Handler).serve_forever()
