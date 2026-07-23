#!/usr/bin/env python3
import base64, json, os, ssl, subprocess, sys, time, urllib.error, urllib.parse, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RUNTIME = '/runtime'
LOG = f'{RUNTIME}/decision.log'
POLICY = f'{RUNTIME}/policy.json'
IDP = 'http://10.90.30.10:8080/realms/ztna'

def emit(event):
    event['time'] = int(time.time())
    with open(LOG, 'a', encoding='utf8') as out:
        out.write(json.dumps(event, sort_keys=True) + '\n')

def pki():
    os.makedirs(f'{RUNTIME}/clients', exist_ok=True)
    if os.path.exists(f'{RUNTIME}/ca.crt'):
        return
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',f'{RUNTIME}/ca.key','-out',f'{RUNTIME}/ca.crt','-days','2','-subj','/CN=ztna-lab-ca'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['openssl','req','-newkey','rsa:2048','-nodes','-keyout',f'{RUNTIME}/pep.key','-out',f'{RUNTIME}/pep.csr','-subj','/CN=pep.ztna.lab','-addext','subjectAltName=DNS:pep.ztna.lab,IP:10.90.20.10'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['openssl','x509','-req','-in',f'{RUNTIME}/pep.csr','-CA',f'{RUNTIME}/ca.crt','-CAkey',f'{RUNTIME}/ca.key','-CAcreateserial','-copy_extensions','copy','-out',f'{RUNTIME}/pep.crt','-days','2'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def issue(name):
    pki()
    key = f'{RUNTIME}/clients/{name}.key'
    csr = f'{RUNTIME}/clients/{name}.csr'
    crt = f'{RUNTIME}/clients/{name}.crt'
    subprocess.run(['openssl','req','-newkey','rsa:2048','-nodes','-keyout',key,'-out',csr,'-subj',f'/CN={name}.ztna.lab'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['openssl','x509','-req','-in',csr,'-CA',f'{RUNTIME}/ca.crt','-CAkey',f'{RUNTIME}/ca.key','-CAcreateserial','-out',crt,'-days','2'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def claim(token):
    try:
        payload = token.split('.')[1] + '=' * (-len(token.split('.')[1]) % 4)
        data = json.loads(base64.urlsafe_b64decode(payload))
        audience = data.get('aud', [])
        if not isinstance(audience, list):
            audience = [audience]
        if data.get('iss') != IDP or 'pep' not in audience:
            return None, 'issuer-or-audience'
        form = urllib.parse.urlencode({'client_id':'pep','client_secret':'LAB-ONLY-PEP-SECRET','token':token}).encode()
        reply = urllib.request.urlopen(urllib.request.Request(f'{IDP}/protocol/openid-connect/token/introspect', form), timeout=3).read()
        active = json.loads(reply)
        if not active.get('active'):
            return None, 'inactive-token'
        return active, ''
    except (IndexError, KeyError, ValueError, urllib.error.URLError, json.JSONDecodeError):
        return None, 'invalid-token'

def rules():
    try:
        with open(POLICY, encoding='utf8') as source:
            return json.load(source)
    except (FileNotFoundError, json.JSONDecodeError):
        return {'resources': {}}

class Service(BaseHTTPRequestHandler):
    server_version = 'ztna-lab'
    def send(self, status, body, content='application/json'):
        value = json.dumps(body, sort_keys=True).encode() if isinstance(body, dict) else body.encode()
        self.send_response(status)
        self.send_header('Content-Type', content)
        self.send_header('Content-Length', str(len(value)))
        self.end_headers()
        self.wfile.write(value)
    def log_message(self, *_):
        pass
    def do_GET(self):
        role = self.server.role
        if role == 'app':
            return self.send(200, {'origin': os.environ['ROLE'], 'path': self.path, 'request_id': self.headers.get('X-Request-ID','missing')})
        if role == 'log':
            try:
                body = open(LOG, encoding='utf8').read()
            except FileNotFoundError:
                body = ''
            return self.send(200, body, 'application/x-ndjson')
        if role == 'pki':
            return self.send(200, {'ca': '/runtime/ca.crt', 'issue': 'POST /issue/<client-name>'})
        if self.path == '/healthz':
            return self.send(200, {'ready': True})
        path = self.path.split('?')[0]
        resource = 'public' if path.startswith('/public') else ('partner' if path.startswith('/partner') else 'finance' if path.startswith('/finance') else 'ops' if path.startswith('/ops') else None)
        request_id = self.headers.get('X-Request-ID', f'r-{time.time_ns()}')
        if not resource:
            emit({'decision':'deny','reason':'unknown-resource','request_id':request_id})
            return self.send(404, {'decision':'deny'})
        rule = rules().get('resources', {}).get(resource)
        if resource == 'public':
            rule = {'anonymous': True, 'origin':'10.90.40.10'}
        if not rule:
            emit({'decision':'deny','resource':resource,'reason':'no-policy','request_id':request_id})
            return self.send(403, {'decision':'deny','reason':'no-policy'})
        info, why = (None, '') if rule.get('anonymous') else claim(self.headers.get('Authorization','').removeprefix('Bearer ').strip())
        groups = [] if not info else info.get('groups', [])
        cert = self.connection.getpeercert() if hasattr(self.connection, 'getpeercert') else None
        if not rule.get('anonymous') and not info:
            emit({'decision':'deny','resource':resource,'reason':why,'request_id':request_id})
            return self.send(401, {'decision':'deny','reason':why})
        if rule.get('groups') and not any(g in groups for g in rule['groups']):
            emit({'decision':'deny','resource':resource,'user':info.get('preferred_username'),'reason':'group','request_id':request_id})
            return self.send(403, {'decision':'deny','reason':'group'})
        if rule.get('mtls') and not cert:
            emit({'decision':'deny','resource':resource,'user':info.get('preferred_username'),'reason':'device-certificate','request_id':request_id})
            return self.send(403, {'decision':'deny','reason':'device-certificate'})
        try:
            req = urllib.request.Request(f"http://{rule['origin']}:8080{path}", headers={'X-Request-ID':request_id})
            body = urllib.request.urlopen(req, timeout=3).read().decode()
        except urllib.error.URLError:
            emit({'decision':'deny','resource':resource,'reason':'origin-unavailable','request_id':request_id})
            return self.send(502, {'decision':'deny','reason':'origin-unavailable'})
        emit({'decision':'permit','resource':resource,'user':'anonymous' if not info else info.get('preferred_username'),'device':'cert' if cert else 'none','request_id':request_id})
        return self.send(200, body)
    def do_POST(self):
        if self.server.role == 'pki' and self.path.startswith('/issue/'):
            name = self.path.rsplit('/', 1)[1]
            if name != 'managed-client':
                return self.send(400, {'error':'only managed-client is enrolled in this lab'})
            issue(name)
            return self.send(201, {'issued':name})
        return self.send(404, {'error':'not-found'})

def main():
    role = sys.argv[1]
    if role == 'pep':
        pki()
        httpd = ThreadingHTTPServer(('0.0.0.0', 8443), Service)
        httpd.role = role
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(f'{RUNTIME}/pep.crt', f'{RUNTIME}/pep.key')
        context.verify_mode = ssl.CERT_OPTIONAL
        context.load_verify_locations(f'{RUNTIME}/ca.crt')
        httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    else:
        httpd = ThreadingHTTPServer(('0.0.0.0', 8080), Service)
        httpd.role = role
    httpd.serve_forever()

if __name__ == '__main__':
    main()
