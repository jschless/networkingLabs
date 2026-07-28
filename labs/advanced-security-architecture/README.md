# Advanced Security Architecture — Practice Capstone

Build and defend an enterprise security path from an internet edge through
stateful policy, NAT, inline IDS/IPS, a WAF/resource PEP, VRF-separated users
and servers, controlled DNS/web egress, OOB management, centralized evidence,
and an expiring RTBH response. This is a Linux mechanism lab: nftables,
Suricata, nginx/ModSecurity, dnsmasq, Squid, and a small resource PEP are named
as themselves, never as a commercial NGFW or “application ID.”

Prerequisites: complete the Security and SOC tracks, then
`zero-trust-secure-access` and `internet-peering-ixp`. The PEP consumes an
already issued assertion; identity-provider administration is deliberately not
repeated here.

## Topology

```text
  192.0.2.10          192.0.2.1  198.51.100.1     198.51.100.2
 [internet-test] -------- [edge] ------------------- [ngfw]
                                                        |
                 +----------------------+---------------+------------------+
                 |                      |               |                  |
           USER/SERVER VRFs          DMZ zone       partner zone     security services
                 |                      |               |                  |
              [core]                [waf-pep]       [partner]      [DNS/proxy/logs]
              /    \
           [user] [protected-app]                 OOB MGMT VRF
                                                      |
                                        [admin] -- [mgmt LAN] -- [break-glass]
```

The user and server access segments occupy separate Linux VRFs on `core`.
VLANs 110 and 120 carry distinct `/30` transits to `ngfw`, so an inter-zone
packet cannot route locally around the security policy.

### Node reference

| Node | Addressing | Role |
|---|---|---|
| `internet-test` | `192.0.2.10`; loopbacks `203.0.113.53`, `.80`, `.200` | public client, public resolver, approved service, RTBH target |
| `edge` | `192.0.2.1`, `198.51.100.1` | documentation-prefix routing and scoped RTBH API |
| `ngfw` | `198.51.100.2`; `10.114.254.1/.5`; zone gateways | state, NAT, NFQUEUE inspection, rate limit, OOB VRF |
| `core` | VRF transits `10.114.254.2/.6`; `10.114.10.1`, `10.114.20.1` | USER/SERVER VRF separation |
| `user` | `10.114.10.10/24` | internal user source |
| `protected-app` | `10.114.20.20/24` | origin with public, partner, and internal routes |
| `waf-pep` | `10.114.30.10/24` | reverse proxy/WAF on 8080; resource PEP on 8443 |
| `partner` | `10.114.40.10/24` | pre-issued signed partner assertion |
| `admin` | `10.114.50.10/24` | normal OOB administrator |
| `break-glass` | `10.114.50.11/24` | dedicated emergency OOB source |
| `security-services` | `10.114.60.10/24` | DNS, egress proxy, and UTC log collector |

### Routed links and zones

| Link/zone | Prefix | Notes |
|---|---|---|
| internet test LAN | `192.0.2.0/24` | RFC 5737 documentation space |
| edge—gateway | `198.51.100.0/30` | routed WAN transit; public service is `198.51.100.80` |
| USER VRF transit | `10.114.254.0/30` | VLAN 110 |
| SERVER VRF transit | `10.114.254.4/30` | VLAN 120 |
| user | `10.114.10.0/24` | USER VRF |
| server | `10.114.20.0/24` | SERVER VRF |
| DMZ | `10.114.30.0/24` | WAF/PEP |
| partner | `10.114.40.0/24` | untrusted external partner |
| OOB management | `10.114.50.0/24` | gateway interface is in VRF `MGMT` |
| security services | `10.114.60.0/24` | controlled DNS/proxy/logs |

Read the
[policy matrix](https://github.com/jschless/networkingLabs/blob/main/labs/advanced-security-architecture/POLICY-MATRIX.md)
before configuring. Its `Via` column is part of the outcome. The separate
[fidelity/product mapping](https://github.com/jschless/networkingLabs/blob/main/labs/advanced-security-architecture/EVIDENCE-MAPPING.md)
identifies live mechanisms, licensed/optional platforms, and evidence-only
product capabilities.

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure.** When a task asks for a prediction,
  commit to an answer before touching the CLI. Being wrong and finding out
  why is the point.
- **Open the hints before the solution.** The solution toggle is the answer
  key — use it to check your work or when genuinely stuck, not as step one.
- **Verify like an operator.** After each task, prove the state is what you
  think it is with operational evidence before moving on.

Solutions build on earlier tasks and exist only in the collapsed blocks below;
the startup files contain addressing and application scaffolding, not the
withheld security policy.

## Build, deploy, and readiness

Build the two versioned local images once. Registry access is not needed after
these builds:

```bash
docker build -t advanced-security-tools:1.0.0 labs/advanced-security-architecture/
docker build -f labs/advanced-security-architecture/Dockerfile.fw \
  -t advanced-security-fw:1.0.0 labs/advanced-security-architecture/
./scripts/lab.sh deploy advanced-security-architecture
```

Wait on observed services, not a fixed sleep:

```bash
./scripts/lab.sh nodes advanced-security-architecture
./scripts/lab.sh cmd advanced-security-architecture waf-pep -- \
  nginx -t -c /opt/lab/nginx.conf
./scripts/lab.sh cmd advanced-security-architecture security-services -- \
  pgrep -a rsyslogd
./scripts/lab.sh cmd advanced-security-architecture core -- \
  ip route show vrf USER
./scripts/lab.sh cmd advanced-security-architecture core -- \
  ip route show vrf SERVER
```

Open a shell with:

```bash
./scripts/lab.sh bash advanced-security-architecture ngfw
```

## Task 1 — Turn business flows into security decisions (Guided)

**Objective:** Review the supplied policy matrix, identify each trust boundary
and control owner, and state the fail-open/fail-closed choice before installing
policy.

**Predict first:** If a partner request returns HTTP 200 from the origin but
there is no matching PEP or WAF event, is the business flow healthy?

Use these visible commands to establish facts:

```bash
sed -n '1,240p' labs/advanced-security-architecture/POLICY-MATRIX.md
./scripts/lab.sh cmd advanced-security-architecture core -- ip -d link show USER
./scripts/lab.sh cmd advanced-security-architecture core -- ip -d link show SERVER
./scripts/lab.sh cmd advanced-security-architecture ngfw -- ip -d link show MGMT
```

Record the source, destination, service, decision, required path, log owner,
and rollback owner for every matrix row. NFQUEUE will be fail-closed once
installed; the public service and identity route are also fail-closed.
Break-glass is a narrow alternative management source, not a data-plane bypass.

<details markdown="1">
<summary>Check your work</summary>

`USER`, `SERVER`, and `MGMT` report VRF table 1010, 1020, and 1050. The answer
to the prediction is **no**: reachability without PEP/WAF evidence proves a
bypass. A routed path, a stateful permit, and an application permit are three
different decisions.

</details>

## Task 2 — Establish explicit stateful zone policy (Hinted)

**Objective:** Create default-deny input/forward policy, preserve stateful
return traffic, permit the one internal application flow, central security
logging, and OOB management only from the two named sources.

**Predict first:** Which rule must be evaluated before all new-flow permits,
and what happens to a reply packet if it is omitted?

<details markdown="1">
<summary>Hints</summary>

- Use an `inet` table with base chains at the `input` and `forward` hooks.
- Put `ct state established,related` before new-flow permits.
- At the input hook, a VRF-arrived packet reports `iifname "MGMT"`, not its
  enslaved physical interface.
- USER-to-SERVER crosses `eth2.110` to `eth2.120`.

</details>

<details markdown="1">
<summary>Solution</summary>

Open `ngfw` with `./scripts/lab.sh bash advanced-security-architecture ngfw`,
then enter:

```nftables
nft -f - <<'EOF'
table inet asa {
  chain input {
    type filter hook input priority 0; policy drop;
    iifname "lo" accept
    ct state established,related counter accept comment "stateful management return"
    ct state invalid counter drop
    iifname "MGMT" ip saddr { 10.114.50.10, 10.114.50.11 } tcp dport 8443 counter accept comment "OOB admin and break-glass VRF"
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related counter accept comment "stateful return first"
    ct state invalid counter drop
    iifname "eth2.110" oifname "eth2.120" ip saddr 10.114.10.10 ip daddr 10.114.20.20 tcp dport 8080 counter accept comment "user to internal app"
    iifname { "eth2.110", "eth2.120", "eth3", "eth4" } oifname "eth5" ip daddr 10.114.60.10 udp dport 514 counter accept comment "central security logging"
  }
}
EOF
```

</details>

<details markdown="1">
<summary>Check your work</summary>

```bash
nft -a list table inet asa
```

The established/related rule appears first in `forward`. From `user`,
`/internal-app` succeeds, while TCP/8443 on the origin fails. Admin and
break-glass reach `10.114.50.1:8443`; the user does not. The prediction resolves
to the state rule: without it, the default-drop chain discards the reply.

</details>

## Task 3 — Publish only through the WAF (Hinted)

**Objective:** Add exact public and hairpin DNAT, WAF-to-origin policy, a public
rate limit, and a deterministic benign ModSecurity action. Direct private WAF
and origin access must remain denied.

**Predict first:** Does DNAT alone authorize a packet through a default-drop
forward chain?

<details markdown="1">
<summary>Hints</summary>

- Match `ct status dnat` on the public permit so direct private addressing
  cannot borrow the publication rule.
- Put the excess-rate drop before the public accept.
- The safe WAF marker is the literal query value `LAB-WAF-SAFE-TEST`; it is not
  an exploit payload.

</details>

<details markdown="1">
<summary>Solution</summary>

In the `ngfw` shell:

```nftables
nft add rule inet asa forward iifname "eth1" oifname "eth3" ct status dnat ip daddr 10.114.30.10 tcp dport 8080 limit rate over 20/second burst 10 packets counter drop comment '"public WAF rate limit"'
nft add rule inet asa forward iifname "eth1" oifname "eth3" ct status dnat ip daddr 10.114.30.10 tcp dport 8080 counter accept comment '"published public app through WAF"'
nft add rule inet asa forward iifname "eth2.110" oifname "eth3" ct status dnat ip daddr 10.114.30.10 tcp dport 8080 counter accept comment '"intentional user hairpin through WAF"'
nft add rule inet asa forward iifname "eth3" oifname "eth2.120" ip saddr 10.114.30.10 ip daddr 10.114.20.20 tcp dport 8080 counter accept comment '"WAF to one origin port"'
nft add table ip asa_nat
nft 'add chain ip asa_nat prerouting { type nat hook prerouting priority dstnat; policy accept; }'
nft add rule ip asa_nat prerouting iifname '{ "eth1", "eth2.110" }' ip daddr 198.51.100.80 tcp dport 80 counter dnat to 10.114.30.10:8080 comment '"exact public and hairpin publication"'
nft 'add chain ip asa_nat postrouting { type nat hook postrouting priority srcnat; policy accept; }'
nft add rule ip asa_nat postrouting oifname "eth1" ip saddr 10.114.0.0/16 counter masquerade comment '"documented lab egress NAT"'
```

Open `waf-pep`, then create the live rule and reload from a writable config:

```bash
cat >/etc/nginx/modsecurity-lab.conf <<'EOF'
SecRuleEngine On
SecRequestBodyAccess On
SecAuditEngine RelevantOnly
SecAuditLogType Serial
SecAuditLog /var/log/modsecurity/audit.log
SecRule ARGS:probe "@streq LAB-WAF-SAFE-TEST" "id:1141001,phase:2,deny,status:403,log,msg:'LAB safe WAF marker'"
EOF
sed 's/modsecurity off;/modsecurity on;/' /opt/lab/nginx.conf >/tmp/nginx.conf
nginx -s quit
for _ in $(seq 1 20); do
  ss -lnt | grep -q ':8080 ' || break
  sleep 0.1
done
nginx -c /tmp/nginx.conf
```

</details>

<details markdown="1">
<summary>Check your work</summary>

Public and hairpin requests return the origin JSON; the safe marker returns
403; a normal request remains 200. `conntrack -L -p tcp` shows original
destination `198.51.100.80` and translated source/origin tuple. The answer to
the prediction is **no**: translation selects an address; the stateful policy
still decides whether the flow may pass.

</details>

## Task 4 — Put safe IDS and IPS evidence in the path (Hinted)

**Objective:** Send HTTP request and response packets through Suricata NFQUEUE,
alert on `/ids-alert`, drop only `/ids-block`, and preserve normal service.

**Predict first:** If only the request direction enters NFQUEUE, will
flow-aware HTTP inspection have complete state?

<details markdown="1">
<summary>Hints</summary>

- Start the queue consumer before adding fail-closed queue rules.
- Queue both destination and source ports 3128, 8080, and 8443.
- Use repository-owned SIDs `1140001` and `1140002`.

</details>

<details markdown="1">
<summary>Solution</summary>

In `ngfw`:

```bash
cat >/tmp/asa.rules <<'EOF'
alert http any any -> any any (msg:"LAB safe IDS alert"; flow:established,to_server; http.uri; content:"/ids-alert"; sid:1140001; rev:1;)
drop http any any -> any any (msg:"LAB safe IPS block"; flow:established,to_server; http.uri; content:"/ids-block"; sid:1140002; rev:1;)
EOF
mkdir -p /var/log/suricata
suricata -q 0 -S /tmp/asa.rules -l /var/log/suricata -D
until grep -q 'Engine started' /var/log/suricata/suricata.log; do sleep 0.25; done
nft 'add chain inet asa inspect { type filter hook forward priority -10; policy accept; }'
nft add rule inet asa inspect tcp dport '{ 3128, 8080, 8443 }' counter queue num 0 comment '"fail-closed Suricata request inspection"'
nft add rule inet asa inspect tcp sport '{ 3128, 8080, 8443 }' counter queue num 0 comment '"fail-closed Suricata response inspection"'
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`/ids-alert` completes and appears in `fast.log`; `/ids-block` times out and
has a `[Drop]` event; `/public-app` still returns 200. Queue counters advance in
both directions. The prediction resolves to **no**: the response direction is
needed for complete TCP/application state.

</details>

## Task 5 — Enforce controlled DNS (Hinted)

**Objective:** Permit the user to resolve through `security-services`, refuse
`blocked.test`, deny direct use of `203.0.113.53`, and retain source/query
evidence.

**Predict first:** Why is a successful query to the controlled resolver
insufficient proof that resolver bypass is blocked?

<details markdown="1">
<summary>Hints</summary>

- Permit both UDP and TCP 53 to `10.114.60.10`, but no WAN DNS from USER.
- `address=/blocked.test/` produces a negative answer; an address of `#`
  produces `0.0.0.0` instead.

</details>

<details markdown="1">
<summary>Solution</summary>

Add on `ngfw`:

```nftables
nft add rule inet asa forward iifname "eth2.110" oifname "eth5" ip saddr 10.114.10.10 ip daddr 10.114.60.10 udp dport 53 counter accept comment '"user controlled DNS UDP"'
nft add rule inet asa forward iifname "eth2.110" oifname "eth5" ip saddr 10.114.10.10 ip daddr 10.114.60.10 tcp dport 53 counter accept comment '"user controlled DNS TCP"'
```

On `security-services`:

```bash
cat >/tmp/dnsmasq-lab.conf <<'EOF'
no-resolv
bind-interfaces
listen-address=10.114.60.10
address=/approved.test/203.0.113.80
address=/blocked.test/
log-queries
log-facility=/var/log/asa/central.log
EOF
dnsmasq --conf-file=/tmp/dnsmasq-lab.conf
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`dig @10.114.60.10 approved.test A` returns `203.0.113.80`; `blocked.test`
returns no address. The same approved query sent to `203.0.113.53` times out.
The central log includes `query[A]`, the name, and source `10.114.10.10`.
Positive controlled DNS alone does not test the bypass path; both probes are
required.

</details>

## Task 6 — Constrain web egress through a proxy (Hinted)

**Objective:** Permit only the user-to-proxy and proxy-to-documentation-service
paths. Allow `approved.test`, deny `blocked.test`, and deny direct HTTP.

**Predict first:** Is this destination allowlist CASB, DLP, malware sandboxing,
or vendor application identification?

<details markdown="1">
<summary>Hints</summary>

- USER reaches TCP/3128 only on `10.114.60.10`.
- The proxy reaches TCP/8080 only inside `203.0.113.0/24`.
- Squid policy is an explicit domain allowlist; name it precisely.

</details>

<details markdown="1">
<summary>Solution</summary>

On `ngfw`:

```nftables
nft add rule inet asa forward iifname "eth2.110" oifname "eth5" ip saddr 10.114.10.10 ip daddr 10.114.60.10 tcp dport 3128 counter accept comment '"user controlled proxy"'
nft add rule inet asa forward iifname "eth5" oifname "eth1" ip saddr 10.114.60.10 ip daddr 203.0.113.0/24 tcp dport 8080 counter accept comment '"security service approved test egress"'
```

On `security-services`:

```bash
cat >/tmp/squid-lab.conf <<'EOF'
http_port 3128
acl approved dstdomain .approved.test
http_access allow approved
http_access deny all
dns_nameservers 10.114.60.10
access_log stdio:/var/log/squid/access.log
cache_log /var/log/squid/cache.log
pid_filename /run/squid.pid
coredump_dir /var/spool/squid
EOF
mkdir -p /var/spool/squid /var/log/squid
chown -R proxy:proxy /var/spool/squid /var/log/squid
rm -f /run/squid.pid
squid -f /tmp/squid-lab.conf
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The approved URL returns 200 through `-x http://10.114.60.10:3128`; the blocked
domain returns 403; direct `203.0.113.80:8080` times out. Squid’s access log
contains source and destination. The prediction resolves to **none of those
products**: this is destination proxy policy only.

</details>

## Task 7 — Enforce the partner resource route (Hinted)

**Objective:** Consume the supplied signed partner assertion and permit exactly
`/partner-app` through the PEP and WAF. Deny `/internal-app` and direct origin
access.

**Predict first:** What evidence distinguishes a PEP denial from a firewall
denial?

<details markdown="1">
<summary>Hints</summary>

- The partner may address only `10.114.30.10:8443`.
- The PEP policy is a group-to-resource list; identity issuance is already
  complete.
- Compare HTTP status and PEP event with a timed-out direct-origin probe.

</details>

<details markdown="1">
<summary>Solution</summary>

On `ngfw`:

```nftables
nft add rule inet asa forward iifname "eth4" oifname "eth3" ip saddr 10.114.40.10 ip daddr 10.114.30.10 tcp dport 8443 counter accept comment '"partner to resource PEP only"'
```

On `waf-pep`:

```bash
printf '%s\n' '{"partner":["/partner-app"]}' >/run/asa/partner-policy.json
```

Use the issued assertion from `partner`:

```bash
token=$(cat /run/partner.token)
curl -H "Authorization: Bearer $token" \
  -H "X-Lab-Event: partner-test" \
  http://10.114.30.10:8443/partner-app
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The approved resource returns origin JSON; `/internal-app` returns 403 and a
PEP `decision=deny`; direct origin access times out and has no PEP/WAF event.
The prediction resolves through that contrast: an application denial returns a
status and decision log, while the default-drop path never reaches the PEP.

</details>

## Task 8 — Exercise rate-limit and RTBH response (Hinted)

**Objective:** Permit the approved RTBH control path, reject wrong tokens or
prefixes, blackhole only `203.0.113.200/32`, and prove automatic expiry without
affecting `203.0.113.80`.

**Predict first:** Which is safer for this lab: a caller-selected prefix and
indefinite lifetime, or an allowlisted prefix with bounded TTL?

<details markdown="1">
<summary>Hints</summary>

- The API accepts only `203.0.113.200/32` and TTL 2–10 seconds.
- Permit `10.114.60.10` to `198.51.100.1:9000`.
- Permit the edge to send RTBH events to the collector.

</details>

<details markdown="1">
<summary>Solution</summary>

On `ngfw`:

```nftables
nft add rule inet asa forward iifname "eth5" oifname "eth1" ip saddr 10.114.60.10 ip daddr 198.51.100.1 tcp dport 9000 counter accept comment '"approved RTBH control path"'
nft add rule inet asa forward iifname "eth1" oifname "eth5" ip saddr 198.51.100.1 ip daddr 10.114.60.10 udp dport 514 counter accept comment '"edge security log"'
```

From `security-services`:

```bash
curl -X POST \
  -H 'Authorization: Bearer LAB-ONLY-RTBH-CONTROL' \
  -H 'Content-Type: application/json' \
  -d '{"prefix":"203.0.113.200/32","ttl":4}' \
  http://198.51.100.1:9000/
```

</details>

<details markdown="1">
<summary>Check your work</summary>

Before the request, both documentation services answer. During the four-second
window only `.200` fails; `.80` stays 200. The target recovers after expiry,
and central logs show install and clear. A wrong token returns 403. The bounded,
allowlisted choice is safer and deterministic.

</details>

## Task 9 — Review ordering and reject shadow policy (Open)

**Objective:** Review handles, hit counters, and this proposed change before it
is deployed:

```text
partner -> protected-server-zone, TCP/8080, allow, place at top
```

Decide whether it is redundant, shadowing, or broader than the policy matrix.
Produce a safer disposition without regressing the public or partner service.

**Predict first:** Which existing controls would stop producing evidence if
the proposal were installed above the intended PEP rule?

<details markdown="1">
<summary>Hints</summary>

- Start with `nft -a list chain inet asa forward`.
- Compare the proposed destination with the PEP address and the protected
  origin address.
- A successful origin request with only an origin log is decisive evidence.

</details>

<details markdown="1">
<summary>Solution</summary>

Reject the proposal rather than reorder it: the matrix permits partner to
`waf-pep:8443`, not to the origin. Keep state/invalid handling first, the
rate-limit drop before the publication accept, and only narrow new-flow rules.
No new rule is required.

Use `nft -a list chain inet asa forward` to record handles and counters, then
run `./scripts/lab.sh check advanced-security-architecture`. A clean policy has
no `BREAKIT` comment and passes the independent partner-origin denial.

</details>

<details markdown="1">
<summary>Check your work</summary>

The proposal is broader and bypasses two application controls. PEP and WAF
events would disappear while the origin still logs HTTP 200. Rejecting the
change produces no service regression and leaves all checks green.

</details>

## Task 10 — Break-It: diagnose the silent partner bypass (Open)

**Objective:** Start from the user-visible symptom “partner access works, but
the expected PEP/WAF event is missing.” Diagnose the actual path without
reading the injector, remove only the shadowing rule, and prove recovery.

**Predict first:** Will the normal public application test detect this fault?

Inject the change:

```bash
labs/advanced-security-architecture/break-it.sh
```

Diagnose from:

```bash
./scripts/lab.sh check advanced-security-architecture
./scripts/lab.sh cmd advanced-security-architecture ngfw -- \
  nft -a list chain inet asa forward
./scripts/lab.sh cmd advanced-security-architecture security-services -- \
  tail -80 /var/log/asa/central.log
```

<details markdown="1">
<summary>Hints</summary>

- Compare direct-origin and PEP requests separately.
- Find a rule with an unexpected nonzero partner-to-SERVER counter.
- For one event ID, look for origin evidence with no PEP/WAF evidence.

</details>

<details markdown="1">
<summary>Solution</summary>

The injected top rule permits `10.114.40.10` directly to
`10.114.20.20:8080`. Its counter increments; the origin logs the request, but
the PEP/WAF do not. Delete only that rule handle:

```bash
labs/advanced-security-architecture/repair-break-it.sh
./scripts/lab.sh check advanced-security-architecture
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The broken check fails only the independent partner-origin denial while normal
public and intended partner tests still pass. After repair, direct origin
access times out, the intended PEP route remains 200, and all checks pass. The
prediction is **no**: the normal public path never crosses the bad partner rule.

</details>

## Make the invisible visible

Use one event ID on a public or partner request:

```bash
event=case-114-001
./scripts/lab.sh cmd advanced-security-architecture internet-test -- \
  curl -H "X-Lab-Event: $event" http://198.51.100.80/public-app
labs/advanced-security-architecture/evidence.sh "$event"
```

The output aligns live nftables/NAT counters with WAF and origin timestamps.
Suricata evidence is path/URI and timestamp based; firewall denials also use an
independent policy-probe result because a dropped packet cannot create an
application log.

## Verification

```bash
./scripts/lab.sh check advanced-security-architecture
```

The check walks all matrix permits and denials, publication and hairpin,
external-zone origin bypass, partner resource scope, management isolation,
DNS/proxy bypass, IDS alert/drop, WAF action, rate limit, NAT/conntrack
symmetry, RTBH authorization/scope/expiry, and correlated logs.

## Challenge questions

1. Which controls must change if the protected origin moves to a different
   SERVER VRF, and which should remain address-independent?
2. How would you choose fail-open versus fail-closed for inline inspection if
   the protected application became safety-critical?
3. Design a two-person break-glass workflow that preserves emergency access
   without turning the OOB source into permanent flat trust.
4. Which fields and retention boundaries would you require before approving
   production TLS decryption?
5. How would you extend the RTBH API to multiple prefixes without allowing an
   operator error to blackhole an aggregate?

## Troubleshooting

**Public address times out, and the DNAT counter is zero**

- Cause: the edge route or exact publication is missing.
- Fix: verify `198.51.100.80/32` points to the gateway, then restore only the
  exact TCP/80 DNAT and `ct status dnat` permit.

**WAF returns 502**

- Cause: WAF-to-origin policy or the SERVER VRF transit is absent.
- Fix: inspect the WAF-origin rule counter and `ip route show vrf SERVER`;
  restore the narrow TCP/8080 conduit.

**All inspected HTTP hangs**

- Cause: fail-closed NFQUEUE exists without a live Suricata consumer.
- Fix: inspect `suricata.log`, start the validated queue consumer, and do not
  replace the queue with an unrecorded fail-open bypass.

**Approved proxy request returns 503**

- Cause: controlled DNS is absent or Squid cannot resolve `approved.test`.
- Fix: verify the DNS matrix first, then `dns_nameservers 10.114.60.10`.

**OOB management pings but TCP/8443 times out**

- Cause: the input rule matched enslaved `eth6` instead of VRF device `MGMT`.
- Fix: match the live input interface shown by counters and retain the two
  exact source addresses.

## Cleanup

```bash
./scripts/lab.sh destroy advanced-security-architecture
docker ps --format '{{.Names}}' | grep '^clab-advanced-security-architecture-' || true
ip -o link show | grep 'advanced-security-architecture' || true
```

Container-local policy, tokens, logs, queues, routes, and service files vanish
with the containers. No host network namespace, tap, overlay disk, or runtime
credential directory is created.
