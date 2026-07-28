#!/usr/bin/env python3
import base64
import hashlib
import hmac
import json
import time

key = b"LAB-ONLY-ADVANCED-SECURITY-KEY"


def encode(value: dict) -> str:
    raw = json.dumps(value, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


header = encode({"alg": "HS256", "typ": "JWT"})
payload = encode({"sub": "partner-engineer", "group": "partner", "exp": int(time.time()) + 86400})
signature = base64.urlsafe_b64encode(
    hmac.new(key, f"{header}.{payload}".encode(), hashlib.sha256).digest()
).rstrip(b"=").decode()
print(f"{header}.{payload}.{signature}")
