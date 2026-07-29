#!/usr/bin/env python3
import http.server
import socket


class DualStackServer(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6
    daemon_threads = True

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("X-Client-Cert") != "managed-valid":
            payload = b"identity-denied\n"
            self.send_response(403)
        else:
            try:
                with socket.create_connection(("10.70.41.40", 8443), 3) as upstream:
                    upstream.sendall(
                        b"GET / HTTP/1.0\r\nHost: origin.hybrid.test\r\n"
                        b"X-PEP-Identity: managed-user\r\n\r\n"
                    )
                    response = b""
                    while True:
                        chunk = upstream.recv(4096)
                        if not chunk:
                            break
                        response += chunk
                if b"protected-origin-ok" not in response:
                    raise RuntimeError("unexpected origin response")
                payload = b"protected-app-ok\n"
                self.send_response(200)
            except (OSError, RuntimeError):
                payload = b"protected-upstream-failed\n"
                self.send_response(502)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        return


DualStackServer(("::", 9443), Handler).serve_forever()
