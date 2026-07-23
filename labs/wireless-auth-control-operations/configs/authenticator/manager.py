from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Inventory(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({
            "service": "pedagogical wireless auth-control inventory",
            "fidelity": "wired EAPOL/RADIUS policy only; not a WLC or RF controller",
            "roles": {"corp": 110, "guest": 120, "quarantine": 130},
            "live_radio": False,
        }, indent=2).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self, fmt, *args):
        return

HTTPServer(("192.168.99.1", 8080), Inventory).serve_forever()
