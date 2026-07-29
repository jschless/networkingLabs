#!/usr/bin/env python3
import http.server
import socket
import sys
import threading


ROLE = sys.argv[1]
RESPONSES = {
    8080: f"cloud-app-{ROLE[-1]}-ok\n",
    8081: f"cloud-health-{ROLE[-1]}-ok\n",
    8443: "protected-origin-ok\n",
}


class DualStackServer(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6
    daemon_threads = True

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        payload = RESPONSES[self.server.server_port].encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        return


servers = [DualStackServer(("::", port), Handler) for port in RESPONSES]
for server in servers:
    threading.Thread(target=server.serve_forever, daemon=True).start()
threading.Event().wait()
