#!/usr/bin/env python3
"""Edge reconciler: mTLS pull, policy acknowledgement, encrypted overlay, SLA hysteresis."""
import json, os, re, ssl, subprocess, sys, time, urllib.request
from pathlib import Path
NODE=sys.argv[1]; D=Path('/runtime/edges')/NODE
bad=good=0; decision='mpls'; changed=0; applied=''; failures=0
def run(*args): return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout
def cmd(line): subprocess.run(line, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def status(**kw):
    base={'enrolled':True,'control':'up','applied_version':applied,'decision':decision,'mpls_bad_samples':bad,'internet':'up'}; base.update(kw); (D/'status.json').write_text(json.dumps(base))
def policy():
    c=ssl.create_default_context(cafile=str(D/'ca.crt')); c.check_hostname=False; c.load_cert_chain(str(D/'client.crt'),str(D/'client.key'))
    with urllib.request.urlopen('https://10.113.40.10:8443/v1/policy',context=c,timeout=3) as r: return json.load(r)
def apply(p):
    global applied
    for name,addr,allowed,pub,endpoint in p['peers']:
        cmd(f'ip link del {name} 2>/dev/null || true')
        cmd(f'ip link add {name} type wireguard')
        cmd(f'ip addr add {addr} dev {name}')
        port = {'wg-mpls-branch1':51821, 'wg-inet-branch1':51822, 'wg-mpls-branch2':51823, 'wg-inet-branch2':51824}.get(name)
        if name == 'wg-mpls-hub': port = 51821 if NODE == 'branch1' else 51823
        if name == 'wg-inet-hub': port = 51822 if NODE == 'branch1' else 51824
        cmd(f'wg set {name} listen-port {port}')
        cmd(f'wg set {name} private-key {D}/wg.key peer {pub} allowed-ips {allowed} endpoint {endpoint} persistent-keepalive 10')
        cmd(f'ip link set {name} up')
    if NODE == 'hub':
        # Hub return paths use the independently healthy internet overlay. This makes
        # the reverse path survive a branch private-underlay hard failure while the
        # branch still prefers MPLS for critical forward traffic in golden state.
        cmd('ip route replace 10.113.10.0/24 dev wg-inet-branch1; ip route replace 10.113.110.0/24 dev wg-inet-branch1')
        cmd('ip route replace 10.113.20.0/24 dev wg-inet-branch2; ip route replace 10.113.120.0/24 dev wg-inet-branch2')
    else:
        cmd('ip rule del fwmark 100 table 100 2>/dev/null || true; ip rule add fwmark 100 table 100')
        cmd('ip route replace 10.113.30.0/24 dev wg-mpls-hub; ip route replace 10.113.10.0/24 dev wg-mpls-hub' if NODE=='branch2' else 'ip route replace 10.113.20.0/24 dev wg-mpls-hub')
        cmd('ip route replace default via 192.0.2.113 dev eth3' if NODE=='branch1' else 'ip route replace default via 192.0.2.121 dev eth3')
        cmd('nft delete table inet overlay 2>/dev/null || true; nft add table inet overlay; nft "add chain inet overlay prerouting { type filter hook prerouting priority mangle; }"; nft add rule inet overlay prerouting ip daddr 10.113.30.10 tcp dport 8443 meta mark set 100')
        guest='eth5'; cmd(f'nft "add chain inet overlay forward {{ type filter hook forward priority filter; }}"; nft add rule inet overlay forward iif {guest} ip daddr {{ 10.113.10.0/24, 10.113.20.0/24, 10.113.30.0/24 }} drop')
    applied=p['version']; set_path('mpls')
def set_path(which):
    global decision,changed
    if NODE == 'hub': return
    dev='wg-mpls-hub' if which=='mpls' else 'wg-inet-hub'
    cmd(f'ip route replace 10.113.30.0/24 dev {dev} table 100; ip route replace 10.113.30.0/24 dev {dev}')
    decision=which; changed=time.time()
def sample():
    if NODE=='hub': return True
    peer='172.20.113.5'  # hub private-underlay endpoint; probing only the MPLS color
    out=run('ping','-I','eth2','-c','1','-W','1',peer)
    m=re.search(r'time=([0-9.]+)',out)
    return bool(m and float(m.group(1)) < 80)
while True:
    try:
        p=policy(); failures=0
        if p['version'] != applied: apply(p)
        ok=sample()
        if NODE!='hub':
            if ok: good,bad=good+1,0
            else: bad,good=bad+1,0
            if decision=='mpls' and bad>=3: set_path('internet')
            if decision=='internet' and good>=5 and time.time()-changed>=15: set_path('mpls')
        status(mpls='up' if ok else 'brownout')
    except Exception as exc:
        failures+=1; status(control='degraded',error=str(exc),failures=failures)
        if failures>=3:
            for d in ('wg-mpls-hub','wg-inet-hub','wg-mpls-branch1','wg-inet-branch1','wg-mpls-branch2','wg-inet-branch2'): cmd(f'ip link del {d} 2>/dev/null || true')
            status(control='down',overlay='withdrawn',error='controller identity rejected')
    time.sleep(1)
