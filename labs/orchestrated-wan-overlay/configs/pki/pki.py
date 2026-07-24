#!/usr/bin/env python3
"""Tiny lab PKI: signs CSRs and publishes its public CA certificate."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import subprocess, tempfile

ROOT = Path('/runtime/pki')
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        if self.path == '/ca.crt':
            self.send_response(200); self.end_headers(); self.wfile.write((ROOT/'ca.crt').read_bytes()); return
        self.send_error(404)
    def do_POST(self):
        if not self.path.startswith('/enroll/'):
            self.send_error(404); return
        node = self.path.rsplit('/', 1)[-1]
        if node not in {'hub', 'branch1', 'branch2'}:
            self.send_error(400, 'unknown edge'); return
        csr = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        with tempfile.TemporaryDirectory() as td:
            p = Path(td); (p/'in.csr').write_bytes(csr)
            check = subprocess.run(['openssl','req','-in',str(p/'in.csr'),'-noout','-subject'], capture_output=True, text=True)
            if check.returncode or f'CN = {node}' not in check.stdout:
                self.send_error(400, 'CSR CN must be enrolled edge identity'); return
            result = subprocess.run(['openssl','x509','-req','-in',str(p/'in.csr'),'-CA',str(ROOT/'ca.crt'),'-CAkey',str(ROOT/'ca.key'),'-CAcreateserial','-out',str(p/'out.crt'),'-days','1','-sha256'], capture_output=True)
            if result.returncode: self.send_error(500, 'signing failed'); return
            self.send_response(201); self.end_headers(); self.wfile.write((p/'out.crt').read_bytes())
HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
