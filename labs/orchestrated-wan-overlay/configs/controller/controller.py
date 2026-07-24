#!/usr/bin/env python3
"""mTLS controller API and desired-state/audit view for the lab."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json, ssl

ROOT, EDGES = Path('/runtime'), Path('/runtime/edges')
NODES = ('hub', 'branch1', 'branch2')
def version(): return (ROOT/'controller/policy-version').read_text().strip()
def key(node):
    p = EDGES/node/'wg.pub'
    return p.read_text().strip() if p.exists() else None
def revoked(serial):
    p = ROOT/'pki/revoked.serials'
    return p.exists() and serial in p.read_text().splitlines()
def peers(node):
    keys = {n:key(n) for n in NODES}
    if not all(keys.values()): return None
    if node == 'branch1': return [
      ['wg-mpls-hub','10.255.113.2/30','0.0.0.0/0',keys['hub'],'172.20.113.5:51821'],
      ['wg-inet-hub','10.255.113.10/30','0.0.0.0/0',keys['hub'],'192.0.2.116:51822']]
    if node == 'branch2': return [
      ['wg-mpls-hub','10.255.113.6/30','0.0.0.0/0',keys['hub'],'172.20.113.5:51823'],
      ['wg-inet-hub','10.255.113.14/30','0.0.0.0/0',keys['hub'],'192.0.2.116:51824']]
    return [
      ['wg-mpls-branch1','10.255.113.1/30','0.0.0.0/0',keys['branch1'],'172.20.113.1:51821'],
      ['wg-inet-branch1','10.255.113.9/30','0.0.0.0/0',keys['branch1'],'192.0.2.112:51822'],
      ['wg-mpls-branch2','10.255.113.5/30','0.0.0.0/0',keys['branch2'],'172.20.113.9:51823'],
      ['wg-inet-branch2','10.255.113.13/30','0.0.0.0/0',keys['branch2'],'192.0.2.120:51824']]
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def send_json(self, code, data):
        blob=json.dumps(data).encode(); self.send_response(code); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(blob))); self.end_headers(); self.wfile.write(blob)
    def identity(self):
        cert=self.connection.getpeercert() or {}; subject=dict(x[0] for x in cert.get('subject',()))
        return subject.get('commonName'), cert.get('serialNumber')
    def do_GET(self):
        if self.path == '/v1/status':
            states={n:json.loads((EDGES/n/'status.json').read_text()) if (EDGES/n/'status.json').exists() else {} for n in NODES}
            self.send_json(200, {'desired_version':version(),'edges':states,'audit':(ROOT/'controller/audit.log').read_text().splitlines()[-8:]}); return
        if self.path != '/v1/policy': self.send_error(404); return
        node, serial=self.identity()
        if node not in NODES or revoked(serial): self.send_error(403, 'untrusted, expired, or revoked edge identity'); return
        p=peers(node)
        if not p: self.send_error(409, 'waiting for all enrolled edge keys'); return
        self.send_json(200, {'version':version(),'node':node,'peers':p,'segments':['CORP','GUEST'],'policy':'critical-private=mpls; bulk-saas=internet; guest=local-breakout'})
def main():
    context=ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain('/runtime/controller/controller.crt','/runtime/controller/controller.key')
    context.load_verify_locations('/runtime/pki/ca.crt'); context.verify_mode=ssl.CERT_OPTIONAL
    server=HTTPServer(('0.0.0.0',8443),Handler); server.socket=context.wrap_socket(server.socket,server_side=True); server.serve_forever()
main()
