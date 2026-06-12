# Load Balancer Basics — Practice Lab

Every service you've ever used sits behind a load balancer, yet most network
curricula never make you build one. In this lab you put HAProxy in front of
two web servers in a DMZ segment and work through the decisions every
load-balanced design forces: **L4 vs L7** (and what each layer can and cannot
see), **health checks** (how dead servers leave rotation without the client
noticing), **X-Forwarded-For** (recovering the client IP a proxy hides), and
**NAT-mode balancing** — which preserves the client IP for free but couples
the design to routing, setting up the classic **asymmetric return-path**
failure you'll diagnose from a packet capture.

## Topology

```
                        OUTSIDE  203.0.113.0/29
        client (.2) ────────┬───────────┬──────────────
                            │  (outsw)  │
                       edge (.1)    edge2 (.3)
                            │  (dmzsw)  │
        ────────────────────┴───────────┴──────────────
                        DMZ  172.16.0.0/24
                edge=.1   edge2=.2   lb=.10   web1=.11   web2=.12
```

This is the `enterprise-dmz` placement with the firewall policy stripped out
(the lab is about the load balancer, not nftables filtering): an outside
segment, an edge router, and a DMZ holding the service. `edge2` is a second
router between the same two segments — it carries **no traffic** in the
normal design, and why it matters is the subject of a later task. `outsw`
and `dmzsw` are plain Linux-bridge containers acting as switches.

| Segment | Subnet | Hosts |
|---------|--------|-------|
| OUTSIDE | 203.0.113.0/29 | edge=.1, client=.2, edge2=.3 |
| DMZ | 172.16.0.0/24 | edge=.1, edge2=.2, lb=.10, web1=.11, web2=.12 |

| Node | Role |
|------|------|
| client | the "internet user"; routes to the DMZ via edge (203.0.113.1) |
| edge | primary OUTSIDE↔DMZ router, forwarding enabled; NAT VIP lives here later |
| edge2 | second OUTSIDE↔DMZ router; idle by design |
| lb | HAProxy installed, **not running** — you configure and start it |
| web1 / web2 | nginx backends; default route via edge (172.16.0.1) |

Each backend serves a plain-text identity page that echoes which server
answered, what source IP **it** saw, and any `X-Forwarded-For` header —
that page is your measurement instrument for the whole lab:

```
server: web1
client-ip-seen-by-backend: 203.0.113.2
x-forwarded-for: ''
path: /
```

`labs/load-balancer-basics/haproxy/` on your host is bind-mounted to
`/etc/haproxy` in the lb container — edit `haproxy.cfg` with your normal
editor, then validate/start inside the container.

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure.** When a task asks for a prediction,
  commit to an answer before touching the CLI. Being wrong and finding out
  why is the point.
- **Open the hints before the solution.** The solution toggle is the answer
  key — use it to check your work or when genuinely stuck, not as step one.
- **Verify like an operator.** After each task, prove the state is what you
  think it is with `show` commands before moving on.

## Deploy

```bash
# one-time image build
docker build -t lb-lab:local labs/load-balancer-basics/

./scripts/lab.sh deploy load-balancer-basics
./scripts/lab.sh status load-balancer-basics
```

No cEOS or other licensed image required — everything here is stock Debian.

## Task 1 — Get your bearings

**Objective:** Confirm the client can reach both backends *directly* through
edge, and that HAProxy is installed but not running on lb.

Setup commands, given:

```bash
docker exec clab-load-balancer-basics-client curl -s http://172.16.0.11/
docker exec clab-load-balancer-basics-client curl -s http://172.16.0.12/
docker exec clab-load-balancer-basics-lb pgrep haproxy   # no output = not running
```

<details>
<summary>Check your work</summary>

Both backends answer with their identity page, and
`client-ip-seen-by-backend` is `203.0.113.2` — the client's real address,
because right now nothing sits between client and server except routing.
Remember this value: the whole X-Forwarded-For story in Tasks 2–5 is about
what happens to it. `pgrep` prints nothing — starting HAProxy is your job.

</details>

## Task 2 — A TCP-mode (L4) load balancer

**Objective:** Edit `haproxy/haproxy.cfg` so HAProxy listens on `:80` in
**TCP mode** and balances connections round-robin across web1 and web2.
Start it, and prove from the client that consecutive requests to
`http://172.16.0.10/` alternate backends.

**Predict first:** when the request lands on a backend, what will
`client-ip-seen-by-backend` say — the client's 203.0.113.2, or something
else? Why?

<details>
<summary>Hints</summary>

- You need a `frontend` (with `bind :80` and `mode tcp`) pointing at a
  `backend` (also `mode tcp`) with `balance roundrobin` and two `server`
  lines (`server <name> <ip>:<port>`).
- Validate before starting: `haproxy -c -f /etc/haproxy/haproxy.cfg`.
  Start with `haproxy -D -f /etc/haproxy/haproxy.cfg`. To restart after an
  edit: `pkill haproxy`, then start again.
- Test loop:
  `for i in 1 2 3 4; do curl -s http://172.16.0.10/ | head -2; done`
  (run it on the client).

</details>

<details>
<summary>Solution</summary>

Append to `haproxy/haproxy.cfg`:

```text
frontend www
    bind :80
    mode tcp
    default_backend webfarm

backend webfarm
    mode tcp
    balance roundrobin
    server web1 172.16.0.11:80
    server web2 172.16.0.12:80
```

Then on lb:

```bash
haproxy -c -f /etc/haproxy/haproxy.cfg
haproxy -D -f /etc/haproxy/haproxy.cfg
```

</details>

<details>
<summary>Check your work</summary>

Requests alternate `server: web1` / `server: web2` strictly — that's
round-robin. And the prediction:

```
server: web1
client-ip-seen-by-backend: 172.16.0.10
```

The backend sees **the load balancer's IP**, not the client's. HAProxy is a
*proxy*: the client's TCP connection terminates on lb, and lb opens a brand
new connection to the backend. Two consequences: the backend's logs, ACLs,
and rate limits now see one "client" (the LB), and the return path is
trivially correct because backends answer the LB, not the client. Both
points come back later.

</details>

## Task 3 — Health checks: dead servers leave quietly

**Objective:** Add health checks so HAProxy notices a dead backend and takes
it out of rotation, plus a stats listener on `:8404` so you can *watch* it
happen. Then kill nginx on web1 (`docker exec clab-load-balancer-basics-web1
nginx -s stop`), observe, and bring it back (`... web1 nginx`).

**Predict first:** kill web1's nginx *before* adding health checks and run
six requests — exactly what does the client experience? Then answer: with
checks on, what determines how many requests can still fail after the
backend dies?

<details>
<summary>Hints</summary>

- Health checks are one keyword on each `server` line. Defaults: probe every
  2s, mark DOWN after 3 failures, UP after 2 successes — so detection takes
  roughly 6 seconds.
- Stats: a separate `listen stats` section — `bind :8404`, `mode http`,
  `stats enable`, `stats uri /`. CSV for scripting:
  `curl -s 'http://172.16.0.10:8404/;csv'`.
- Watch the status column flip:
  `curl -s 'http://172.16.0.10:8404/;csv' | awk -F, '$2=="web1"{print $2,$18}'`

</details>

<details>
<summary>Solution</summary>

```text
backend webfarm
    mode tcp
    balance roundrobin
    server web1 172.16.0.11:80 check
    server web2 172.16.0.12:80 check

listen stats
    bind :8404
    mode http
    stats enable
    stats uri /
```

(`pkill haproxy` and start it again to load the change.)

</details>

<details>
<summary>Check your work</summary>

Without checks, half your requests fail for as long as web1 is down — HAProxy
keeps dealing connections to a corpse, the backend refuses, and the client
gets an empty reply. Forever; nothing will ever fix it but the server coming
back.

With checks: for the first few seconds after the kill, a request can still
fail (that's the answer to the prediction — the **check interval × fall
count** window, ~6s at defaults). Then the stats CSV shows `web1 DOWN`,
every request lands on web2, and the client sees a fully healthy service at
half capacity. Restart nginx and within ~4s (rise 2) web1 is back in
rotation. This detection-window math — probes × thresholds vs. how many
requests you're willing to lose — is the actual engineering decision in
every health-check config.

</details>

## Task 4 — Go L7: HTTP mode and X-Forwarded-For

**Objective:** Task 2 ended with backends blind to the real client IP.
Switch frontend and backend to **HTTP mode** and make HAProxy add an
`X-Forwarded-For` header carrying the original client address. Prove it on
the identity page.

**Predict first:** could you have solved this in TCP mode? What does HAProxy
have to *do* to the traffic to be able to add a header — and name one thing
that breaks the moment the traffic is TLS instead of plain HTTP.

<details>
<summary>Hints</summary>

- `mode http` in both the frontend and backend sections (a TCP frontend
  can't feed an HTTP backend).
- The header is one `option` in the frontend.
- The backend identity page prints the header — before the change it shows
  `x-forwarded-for: ''`.

</details>

<details>
<summary>Solution</summary>

```text
frontend www
    bind :80
    mode http
    option forwardfor
    default_backend webfarm

backend webfarm
    mode http
    balance roundrobin
    server web1 172.16.0.11:80 check
    server web2 172.16.0.12:80 check
```

</details>

<details>
<summary>Check your work</summary>

```
server: web1
client-ip-seen-by-backend: 172.16.0.10
x-forwarded-for: '203.0.113.2'
```

The TCP-level source is still the LB (it's still a proxy!), but the
application now has the truth in-band. That's the answer to the prediction:
to inject a header HAProxy must *parse and rewrite the HTTP stream*, which
TCP mode never does — and which is impossible on TLS traffic unless the LB
terminates the TLS itself. L4 vs L7 in one sentence: L4 moves bytes between
sockets; L7 understands and edits the conversation.

</details>

## Task 5 — NAT-mode balancing: no proxy at all

**Objective:** Build a *second*, completely different load balancer — on
**edge**, with nftables, no proxy involved. Clients hit a VIP at
`203.0.113.1:8080`; edge DNATs each new connection round-robin to
web1:80 or web2:80. Prove it alternates and compare what the backend sees
with Task 2/4.

**Predict first:** will the backends see the real client IP this time?
There's no proxy and no X-Forwarded-For — reason from what DNAT does and
doesn't rewrite.

<details>
<summary>Hints</summary>

- On edge: a `nat`-type prerouting chain in a new table, then one rule.
  nftables can round-robin a DNAT with `numgen inc mod 2 map { ... }`
  mapping 0/1 to `address . port` pairs.
- Match on `ip daddr 203.0.113.1 tcp dport 8080`.
- Inspect your work: `nft list ruleset`, and
  `conntrack`-free verification: just read the identity pages from the
  client (`curl http://203.0.113.1:8080/`).

</details>

<details>
<summary>Solution</summary>

On edge:

```bash
nft add table ip natlb
nft 'add chain ip natlb pre { type nat hook prerouting priority dstnat; }'
nft 'add rule ip natlb pre ip daddr 203.0.113.1 tcp dport 8080 \
     dnat to numgen inc mod 2 map { 0 : 172.16.0.11 . 80, 1 : 172.16.0.12 . 80 }'
```

</details>

<details>
<summary>Check your work</summary>

```
server: web1
client-ip-seen-by-backend: 203.0.113.2
x-forwarded-for: ''
```

Alternating backends, and the **real client IP is back** — DNAT rewrites
only the destination; the source rides through untouched. No proxy, no
header games, near-zero overhead. So why doesn't everyone do this? Because
the reply must flow back through the *same* NAT device to get un-translated
— the design now depends on routing in a way the proxy never did. The next
task weaponizes exactly that.

</details>

## Task 6 — Break it: the service half-dies

**Objective:** From the lab directory on your host, run:

```bash
./break.sh
```

Then exercise both VIPs from the client. Diagnose **from the symptom**,
find the root cause, and repair it. Don't read `break.sh` — that's the
answer key. You may inspect anything on any node (`ip route`, `nft list
ruleset`, tcpdump are all fair game).

**Predict first:** nothing to predict — but before touching anything, write
down the symptom *precisely*: which VIP fails, how often, and what does
"fails" look like (refused? timeout? wrong content?). Precision here is most
of the diagnosis.

<details>
<summary>Hints</summary>

- Characterize first: requests to `http://203.0.113.1:8080/` vs
  `http://172.16.0.10/`, several of each. One of these is perfectly healthy.
  What do the failing requests have in common?
- "Every second request to the NAT VIP times out" + "round-robin" should
  point you at *one backend's path*, not at the VIP itself.
- The decisive evidence is a packet capture on the client:
  `tcpdump -ni eth1 'tcp port 8080 or tcp port 80'` while a failing request
  runs. Look at the **source address** of the SYN-ACK and ask: who did the
  client actually talk to, and what did its kernel do about the answer?

</details>

<details>
<summary>Solution</summary>

`break.sh` changed **web1's default route** to point at edge2
(`ip route replace default via 172.16.0.2`).

The HAProxy VIP doesn't care: lb↔web1 traffic never leaves the DMZ subnet,
and lb's own replies to the client go via lb's (correct) gateway. But the
NAT path is now asymmetric for web1: client→VIP arrives via **edge** (which
DNATs and forwards), while web1's SYN-ACK to 203.0.113.2 leaves via
**edge2** — which happily delivers it to the client *un-translated*, source
`172.16.0.11:80`. The capture on the client shows the whole story:

```
client.46020 > 203.0.113.1.8080: Flags [S]        ← SYN to the VIP
172.16.0.11.80 > client.46020:   Flags [S.]       ← SYN-ACK from... who?!
client.46020 > 172.16.0.11.80:   Flags [R]        ← kernel: never met you. RST.
(SYN retransmits, same loop, curl times out)
```

The client's kernel has a socket to `203.0.113.1:8080`, not to
`172.16.0.11:80`, so the SYN-ACK matches nothing and is RST. Requests
balanced to web2 (symmetric path) work; web1's all hang — hence "every
second request".

Fix — restore the symmetric return:

```bash
docker exec clab-load-balancer-basics-web1 ip route replace default via 172.16.0.1
```

Then re-verify both VIPs and run `./scripts/lab.sh check load-balancer-basics`.

</details>

<details>
<summary>Check your work</summary>

Both VIPs alternate cleanly again and `check.sh` passes. The transferable
lesson: **NAT-based load balancing turns "return traffic must transit the
same box" into an invisible invariant** — broken not by touching the LB but
by an innocent routing change two hops away (the on-call's "nobody changed
the load balancer!" is true and irrelevant). Proxies sidestep this by
terminating connections; the production-grade NAT answers are source-NAT on
the balancer (and you lose the client IP again — TANSTAAFL) or designs like
LVS direct-return where the VIP lives on every backend's loopback.

</details>

## Task 7 — Open: split the service, survive a failure

**Objective:** Product wants `/api` served exclusively by web2 (it has the
new code), everything else round-robin as before — but if web2 dies, `/api`
must degrade to web1 rather than go dark. Build it in HAProxy, then prove
both properties from the client: path routing while healthy, fallback while
web2's nginx is stopped.

No step-by-step hints — Tasks 2–4 contain every building block. One nudge:
HAProxy routes with `acl` + `use_backend`, and a `server` line can be marked
as standby.

<details>
<summary>Solution</summary>

```text
frontend www
    bind :80
    mode http
    option forwardfor
    acl is_api path_beg /api
    use_backend apifarm if is_api
    default_backend webfarm

backend webfarm
    mode http
    balance roundrobin
    server web1 172.16.0.11:80 check
    server web2 172.16.0.12:80 check

backend apifarm
    mode http
    balance roundrobin
    server web2 172.16.0.12:80 check
    server web1 172.16.0.11:80 check backup
```

</details>

<details>
<summary>Check your work</summary>

While healthy: `curl http://172.16.0.10/api` answers `server: web2` every
time (the identity page's `path:` line confirms what was requested), while
`/` still alternates. Stop web2's nginx, wait out the detection window
(~6s), and `/api` answers `server: web1` — the `backup` server only receives
traffic when every non-backup server in the backend is DOWN. Restart nginx
on web2 and `/api` returns to it. Note what you just built: content-aware
routing plus automatic degradation — the two features that, more than raw
balancing, are why the L7 proxy owns the front of almost every real
deployment.

</details>

## Verification

With Tasks 2–6 complete (Task 7 doesn't change the checked behavior):

```bash
./scripts/lab.sh check load-balancer-basics
```

All 12 checks pass on a correctly finished lab. Manually:

- [ ] `http://172.16.0.10/` alternates backends; backends see lb's IP; XFF carries `203.0.113.2`
- [ ] stats page shows both servers UP; killing one flips it DOWN in ~6s with no client-visible errors after detection
- [ ] `http://203.0.113.1:8080/` alternates backends; backends see the real client IP, empty XFF
- [ ] after break.sh + your fix, both VIPs are healthy again

## Challenge questions

No answers provided — argue them from what you just built.

1. Rank the three balancing styles you used or discussed (L7 proxy, L4 DNAT,
   direct-return/DSR) on: preserving client IP, per-connection overhead, and
   "how much of the rest of the network must cooperate for it to work."
2. `X-Forwarded-For` is just a header, and clients can send one of their own
   before your proxy appends to it. What does a backend have to know about
   the proxy chain to read it safely, and what goes wrong if a backend
   blindly trusts the first address in the list?
3. Your Task 3 health check is a TCP connect probe. The app it guards starts
   returning HTTP 500 on every request while still accepting connections —
   what does your LB do, and how would you fix the check? What's the cost of
   very aggressive checks across a 500-server farm?
4. Where should TLS terminate in this topology — lb, the backends, or both
   (re-encrypt)? For each choice: what happens to X-Forwarded-For, and what
   does a compromise of the DMZ segment expose?
5. In the Task 6 incident, the LB config was provably untouched. Name three
   *other* changes elsewhere in a network that produce the same
   "asymmetric-return" signature, and one monitoring signal that would catch
   the class of problem rather than this one instance.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `haproxy -c` fails with a parse error | Section keywords misplaced (e.g. `option forwardfor` in a `tcp` section is ignored/invalid contextually) | Read the error's line number; keep frontend/backend modes matched |
| `curl http://172.16.0.10/` refused | HAProxy not running (it never starts by itself) | `haproxy -D -f /etc/haproxy/haproxy.cfg` on lb |
| Old config still in effect after editing | A previous haproxy daemon still running | `pkill haproxy`, then start again |
| Both VIPs work but one backend never answers | Its nginx died (Task 3 leftovers) | `docker exec ...-webN nginx` |
| NAT VIP: every request lands on the same backend | `numgen inc` rule fired but conntrack pins flows; you're reusing one connection | curl makes a new connection each run — check the rule with `nft list ruleset`; per-*connection* (not per-packet) balance is correct behavior |
| NAT VIP times out for some/all requests | Return-path asymmetry (a backend's gateway isn't edge) | `ip route` on web1/web2 — default must be 172.16.0.1; see Task 6 |
| Stats page refused | `listen stats` section missing/typo'd, or wrong port | It's `:8404`, `mode http`, `stats uri /` |

## Extensions

- **DSR by hand**: put the VIP on a loopback on both backends, have edge
  route (not NAT) VIP traffic to them, and let replies go straight to the
  client. What ARP problem do you have to solve on the DMZ segment, and why
  does the client accept replies it gets this way?
- **Sticky sessions**: `balance source` vs `cookie SRV insert` — implement
  both, then explain which one survives the client changing IPs (mobile
  roaming) and which survives a backend restart.
- **Active/active NAT**: add the same nftables VIP on edge2 and put both
  routers' addresses in client DNS round-robin. What new failure modes did
  you just buy, and what does conntrack synchronization (e.g. conntrackd)
  exist to solve?
- Compare with the `enterprise-dmz` lab: where would this LB sit in the full
  dual-firewall design, and which firewall policies have to change?
