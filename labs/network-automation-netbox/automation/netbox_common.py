#!/usr/bin/env python3
"""Small, bounded NetBox API helpers shared by the lab workflows."""

import os
import time
from urllib.parse import urljoin

import pynetbox
import requests


NETBOX_URL = os.environ.get("NETBOX_URL", "http://172.31.40.23:8080").rstrip("/")
NETBOX_TOKEN = os.environ.get("NETBOX_TOKEN")
NETBOX_USERNAME = os.environ.get("NETBOX_USERNAME", "admin")
NETBOX_PASSWORD = os.environ.get("NETBOX_PASSWORD", "admin")
REQUEST_TIMEOUT = 20


class LabModelError(RuntimeError):
    """Raised when dedicated-lab data is absent, duplicated, or inconsistent."""


def ensure_token(description):
    """Return an explicit token, or provision one with disposable lab credentials."""
    if NETBOX_TOKEN:
        return NETBOX_TOKEN

    response = requests.post(
        f"{NETBOX_URL}/api/users/tokens/provision/",
        json={
            "username": NETBOX_USERNAME,
            "password": NETBOX_PASSWORD,
            "write_enabled": True,
            "description": description,
        },
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    return response.json()["key"]


def build_clients(description):
    token = ensure_token(description)
    netbox = pynetbox.api(NETBOX_URL, token=token)
    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Token {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
    )
    return netbox, session, token


def wait_for_authenticated_status(timeout_seconds, interval_seconds, description):
    """Poll token provisioning plus authenticated status until a bounded deadline."""
    deadline = time.monotonic() + timeout_seconds
    last_error = "NetBox has not answered yet"
    while time.monotonic() < deadline:
        try:
            _, session, _ = build_clients(description)
            status = api_get(session, "/api/status/")
            return status
        except (KeyError, requests.RequestException) as exc:
            last_error = str(exc)
            remaining = deadline - time.monotonic()
            if remaining > 0:
                time.sleep(min(interval_seconds, remaining))
    raise TimeoutError(
        f"authenticated NetBox readiness timed out after {timeout_seconds}s: "
        f"{last_error}"
    )


def get_unique(endpoint, label, lookup):
    matches = list(endpoint.filter(**lookup))
    if len(matches) > 1:
        raise LabModelError(f"{label}: expected at most one object, found {len(matches)}")
    return matches[0] if matches else None


def ensure_object(endpoint, lookup, payload, label=None):
    obj = get_unique(endpoint, label or str(lookup), lookup)
    if obj:
        obj.update(payload)
        return endpoint.get(id=obj.id) or obj
    return endpoint.create(payload)


def api_get(session, path, params=None):
    response = session.get(
        urljoin(f"{NETBOX_URL}/", path.lstrip("/")),
        params=params,
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    return response.json()


def api_post(session, path, payload, accept="application/json"):
    headers = dict(session.headers)
    headers["Accept"] = accept
    response = session.post(
        urljoin(f"{NETBOX_URL}/", path.lstrip("/")),
        json=payload,
        headers=headers,
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    return response.text if accept == "text/plain" else response.json()


def api_patch(session, path, payload):
    response = session.patch(
        urljoin(f"{NETBOX_URL}/", path.lstrip("/")),
        json=payload,
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    return response.json()


def paginated_results(session, path, params=None):
    query = dict(params or {})
    query.setdefault("limit", 0)
    data = api_get(session, path, params=query)
    if isinstance(data, dict) and "results" in data:
        return data["results"]
    return data
