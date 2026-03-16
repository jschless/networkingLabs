#!/usr/bin/env python3
import os
from urllib.parse import urljoin

import pynetbox
import requests


NETBOX_URL = os.environ.get("NETBOX_URL", "http://172.31.40.23:8080").rstrip("/")
NETBOX_TOKEN = os.environ.get("NETBOX_TOKEN")
NETBOX_USERNAME = os.environ.get("NETBOX_USERNAME", "admin")
NETBOX_PASSWORD = os.environ.get("NETBOX_PASSWORD", "admin")


def ensure_token(description):
    if NETBOX_TOKEN:
        return NETBOX_TOKEN

    resp = requests.post(
        f"{NETBOX_URL}/api/users/tokens/provision/",
        json={
            "username": NETBOX_USERNAME,
            "password": NETBOX_PASSWORD,
            "write_enabled": True,
            "description": description,
        },
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json()["key"]


def build_clients(description):
    token = ensure_token(description)
    nb = pynetbox.api(NETBOX_URL, token=token)
    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Token {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
    )
    return nb, session, token


def ensure_object(endpoint, lookup, payload):
    obj = endpoint.get(**lookup)
    if obj:
        obj.update(payload)
        return endpoint.get(id=obj.id) or obj
    return endpoint.create(payload)


def api_get(session, path, params=None):
    resp = session.get(urljoin(f"{NETBOX_URL}/", path.lstrip("/")), params=params, timeout=20)
    resp.raise_for_status()
    return resp.json()


def api_post(session, path, payload, accept="application/json"):
    headers = dict(session.headers)
    headers["Accept"] = accept
    resp = session.post(
        urljoin(f"{NETBOX_URL}/", path.lstrip("/")),
        json=payload,
        headers=headers,
        timeout=20,
    )
    resp.raise_for_status()
    return resp.text if accept == "text/plain" else resp.json()


def paginated_results(session, path, params=None):
    params = dict(params or {})
    if "limit" not in params:
        params["limit"] = 0
    data = api_get(session, path, params=params)
    if isinstance(data, dict) and "results" in data:
        return data["results"]
    return data
