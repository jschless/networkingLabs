#!/usr/bin/env python3
"""Minimal alert webhook receiver (stand-in for PagerDuty/Slack/Opsgenie).

Listens on :8080 and pretty-prints every Alertmanager POST to stdout, so the
on-call view of Lab 13 is just `docker logs -f hook1`.
"""
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer


class Hook(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
        try:
            payload = json.loads(body)
            alerts = payload.get("alerts", [])
            print(f"--- {stamp} received {len(alerts)} alert(s) "
                  f"[group status: {payload.get('status', '?')}] ---", flush=True)
            for a in alerts:
                labels = a.get("labels", {})
                summary = a.get("annotations", {}).get("summary", "")
                print(f"  [{a.get('status', '?').upper():8s}] "
                      f"{labels.get('alertname', '?')} "
                      f"severity={labels.get('severity', '?')} "
                      f"instance={labels.get('instance', '?')} {summary}",
                      flush=True)
        except (ValueError, KeyError):
            print(f"--- {stamp} non-JSON POST ---\n{body!r}", flush=True)
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):  # silence per-request access log noise
        pass


if __name__ == "__main__":
    print("hook1 webhook receiver listening on :8080", flush=True)
    HTTPServer(("0.0.0.0", 8080), Hook).serve_forever()
