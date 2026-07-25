# Exam E — Answer Key & Grading Notes

The habit this exam grades is **reasoning from evidence to scope**, not vocabulary. Two
things separate a strong paper from a weak one throughout: does the candidate distinguish
*a pattern matched* from *something bad happened*, and do they notice when the evidence says
an attack **succeeded** rather than merely occurred.

---

## Section 1 — Concepts & mechanisms (30)

**E1 (3).** Zeek produces **structured protocol transaction records for all traffic** —
`conn.log`, `http.log`, `dns.log`, `ssl.log`, `files.log` — a description of **what
happened**, entirely independent of whether it was malicious. Suricata produces **alerts**:
a judgement that traffic **matched a signature**. Zeek gives you the network's history;
Suricata gives you an opinion about part of it.

Four `conn.log` fields, any four of: `ts`, `uid`, `id.orig_h`, `id.orig_p`, `id.resp_h`,
`id.resp_p`, `proto`, `service`, `duration`, `orig_bytes`, `resp_bytes`, `conn_state`,
`history`.

**`conn_state`** summarises the outcome of the connection's state machine in a short code —
it is how you tell "established and finished normally" from "nobody ever answered" without
looking at packets. For SYNs to a hundred **closed** ports, the precise answer is **`REJ`**
(the attempt was rejected — a RST came back, so the port is closed but reachable). Award the
mark equally for **`S0`** *if* the candidate explains it as "SYN sent, no reply at all —
filtered or dropped", because that shows they know the state machine; the distinction
between `REJ` and `S0` is exactly the knowledge being tested and it reappears in E-E1.

*1 for the Zeek/Suricata distinction, 1 for four fields, 1 for `conn_state` with a defensible
value and explanation.*

**E2 (3).** A **Suricata alert** is triggered by a **signature matching packet or stream
content** — bytes, ports, protocol fields. It asserts *"this pattern was present"*. A
**Zeek notice** is raised by **Zeek's own analysis scripts** observing behaviour over time
(`Scan::Port_Scan`, `SSL::Invalid_Server_Cert`) — it asserts *"a condition my policy
considers notable was observed"*.

Neither asserts that something bad happened, and the graded insight is saying so. The
Suricata alert is the more purely mechanical claim — a pattern matched, which is why tuning
exists at all. The Zeek notice is a **derived, behavioural** claim, closer to a statement
about events than about bytes. In practice: signatures are better at **precisely identifying
known things**; behavioural notices are better at **catching novel activity that has no
signature yet**.

*2 for the trigger/assertion distinction, 1 for "neither asserts badness" or the
known-vs-novel trade-off.*

**E3 (3).** `event_type` values, any four: **`alert`, `flow`, `http`, `dns`, `tls`,
`fileinfo`, `ssh`, `anomaly`, `stats`**.

Fields needed to triage an `alert` without opening anything else: `timestamp`, `src_ip`,
`src_port`, `dest_ip`, `dest_port`, `proto`, `alert.signature`, `alert.signature_id`,
`alert.category`, `alert.severity`, and — the one candidates forget — **`flow_id` or
`community_id`**, which is what lets you pivot to the connection and to Zeek's record of the
same event. Without a correlation key you have a verdict with no context.

*1.5 for the event types, 1.5 for the triage fields; award the second half fully only if a
correlation identifier appears.*

**E4 (3).**
(a) YARA matches against **file contents, process memory, or any byte buffer** — **not**
network packets. A rule requires a **`condition:`** section (mandatory); **`strings:`** is
what conditions almost always reference, and `meta:` is optional documentation.
(b) YARA sits **after file extraction**. Something must first carve files out of the traffic
— Zeek's file-analysis framework writing `files.log` and extracting to disk — before YARA
has anything to scan. **No extraction, no YARA**, and a file that crossed the wire
encrypted or in an unsupported transport never reaches it.
(c) **YARA good, network signature bad:** identifying a specific malware family **inside a
file regardless of how it arrived, was renamed, or was compressed** — content-based identity
that survives transport, and works on files at rest that never touched the network.
**Network signature good, YARA bad:** anything with **no file** — a C2 beaconing pattern, a
port scan, an exploit attempt against a protocol, or anything about **timing, volume, or
sequence**, which YARA has no concept of.

*1 per part.*

**E5 (3).** Normalisation maps disparate source-specific fields onto a **single common
schema** — `source.ip`, `destination.ip`, `@timestamp`, `rule.name`, `event.severity` — so
that a value means the same thing regardless of which tool produced it.

Without it an analyst **cannot pivot or correlate**. Concretely impossible: searching one IP
address across all three data sources in a single query; joining a Suricata alert to the
Zeek connection that produced it; building one dashboard panel that counts events by source;
writing a correlation rule spanning two tools. Every query has to be rewritten per source,
which means in practice it is written for one source and the others are never consulted.

*2 for the mechanism, 1 for a concrete impossibility. "It makes things consistent" alone
scores 1.*

**E6 (3).**
- **Threshold** — change **how many occurrences are required, or how often an alert may
  fire** (`type threshold` / `limit` / `both`, tracked `by_src` or `by_dst`). Right when the
  detection is **correct but chatty**.
- **Suppression** — **stop the alert entirely** for a specific source/destination/signature
  combination. Right for a **known-good false positive on a specific host** — the authorised
  vulnerability scanner, the monitoring probe.
- **Rule modification** — change the **signature itself** to match more precisely. Right
  when the rule is **genuinely imprecise** and would false-positive across the estate, not
  just here.

**Most dangerous: suppression.** It creates a **permanent, silent blind spot**. If the
suppressed host is later compromised, the detection you most need is disabled and **nothing
in the alert stream records that it was**. Thresholds and rule edits degrade gracefully — you
still see something. Suppression fails invisibly, and under time pressure it tends to get
applied by signature alone rather than signature-plus-host, widening the blind spot far
beyond what was intended.

*2 for the three definitions with a "when", 1 for suppression plus the silent-blind-spot
failure mode.*

**E7 (3).**

| Technique | What it is | In `conn.log` |
|---|---|---|
| **T1046 — Network Service Discovery** | Scanning a host to find what services it runs | One source → **one destination**, **many `id.resp_p`**, mostly `S0`/`REJ`, near-zero duration, empty `service` |
| **T1595 — Active Scanning** | External reconnaissance of the target, including IP-block and web-content scanning | One source → **many destinations**, or many short HTTP connections with `http.log` showing path enumeration |
| **T1110 — Brute Force** | Repeated credential guessing | Many **`SF` (established)** connections to a **single** auth port (22/3389/445) from one source in a tight window — the giveaway is that they **complete**, repeatedly |

**Detection gap** in the `soc-adversary-simulation` sense is **not only "we have no rule"**.
A technique executed and not caught can fail at any of four places, and the remediation
differs at each:
1. **Visibility gap** — no telemetry captured it (sensor not on that segment, traffic
   encrypted, log source not collected).
2. **Detection/rule gap** — telemetry exists but nothing evaluates it.
3. **Tuning gap** — a detection exists but has been thresholded or suppressed into silence.
4. **Response/routing gap** — the detection fired and never reached an analyst.

The detection matrix exists to tell these apart. *Award the third mark only for a candidate
who names more than the missing-rule case.*

**E8 (3).** Ranking, safest to operationalise first:

1. **File hash** — exact and unambiguous; it matches one artefact and can have **zero
   collateral impact**. Its weakness is the mirror image: a one-byte change evades it
   entirely. Precise but brittle.
2. **JA3 / TLS fingerprint** — behavioural, so it **survives IP and domain rotation**, which
   makes it an excellent *detection*. It is a riskier *block*, because a JA3 identifies a
   client **library or stack**, not a program's intent, and legitimate software can share
   one.
3. **Domain name** — reasonably specific, but shared hosting and CDNs mean one domain can
   front benign and malicious content, and fast-flux/DGA erode it quickly.
4. **IP address** — **least safe**. Shared hosting, CDNs, and cloud NAT mean one address can
   serve thousands of unrelated tenants, so a block can cause a wide outage; and
   infrastructure churns fast, so the block quickly protects nothing.

**IOC aging** is expiring or down-weighting an indicator after a defined interval, because
indicators **lose validity as infrastructure is reassigned** — a C2 domain expires and is
re-registered by someone innocent, a cloud IP is recycled within hours. It matters most for
**IP addresses** (recycled fastest, highest collateral) and domains; least for **file
hashes**, which never become someone else's — a hash is permanently bound to its bytes.

*2 for a justified ranking with hashes high and bare IPs low, 1 for aging tied to
type-dependent decay.*

**E9 (3).**
(a) For the same traffic, roughly: **full PCAP ≈ 100%** (it *is* the traffic); **protocol
logs ≈ 0.1–1%**; **flow records ≈ 0.01–0.1%** — flow being the smallest, since one record
summarises an entire conversation. PCAP is two to three **orders of magnitude** larger than
the logs, which is why retention inverts: hours-to-days of PCAP, months of logs, a year or
more of flow.
(b) Two questions only PCAP answers: **"what was actually in the payload"** — the exploit
bytes, the exfiltrated content, the transferred file — and **"what does this look like under
a signature I did not have at the time"**, i.e. **retrospective re-analysis**. The second is
the stronger answer: PCAP lets you ask questions you had not thought of yet.
(c) **"What was inside the TLS session?"** Most traffic is encrypted, so you hold the bytes
and cannot read them — without the session keys or a decryption point, the capture preserves
only ciphertext. (Also accepted: anything that happened **on the host** — PCAP has no
endpoint visibility at all.)

*1 per part.*

**E10 (3).**
- **Observable** — an atomic factual data point extracted from the incident: an IP, hash,
  domain, URL, filename, account. It is what you pivot on and what you export as intel.
- **Containment** — stopping the incident **spreading or continuing**: isolating a host,
  blocking C2, disabling an account. It buys time; the adversary's foothold is still there.
- **Eradication** — removing **the foothold and the means of re-entry**: the malware, the
  persistence mechanism, the compromised credential, the vulnerability that admitted them.

**The timeline is the primary artefact** because an incident **is a sequence**, and nearly
every question that matters is a question about ordering: what came first (initial access),
what happened before the alert (dwell time), what happened after containment (did it work),
and what is in scope (everything touched between t0 and containment). It produces the two
numbers leadership asks for, it is what regulatory reporting requires, and it is the only
representation in which a **gap is visible** — "we have nothing between 02:00 and 06:00" is a
finding you can only see on a timeline. Without one you have a bag of alerts and no
narrative.

**An action that feels like containment and destroys evidence:** **rebooting, powering off,
or reimaging the host.** It destroys volatile memory — running processes, injected code,
open network connections, encryption keys — and usually the malware itself, before anything
is acquired. Also accepted: deleting the malicious file, resetting a compromised account
before capturing its authentication logs and active sessions, or blocking the C2 address
before capturing the beacon traffic that would have identified the family.

*1 for the three definitions, 1 for the timeline argument, 1 for the evidence-destruction
example.*

---

## Section 2 — Evidence reading (20)

### E-E1 (7)

(a) *(3)* A **horizontal port scan of a single host** — `10.20.0.50` sweeping `10.20.0.10`
— **followed by successful interactive access**. The evidence, which must be cited, not just
the label: one source and one destination repeated across **many different `id.resp_p`
values**; almost every row `conn_state S0`, meaning the SYN went out and **nothing came
back**; **no `service`** identified, because nothing ever negotiated; and **no `duration`**,
because no connection was established. One source, one destination, many ports, no
establishment, no duration — that combination is the definitional scan signature.

*2 for the diagnosis, 1 for citing at least three of the four evidential features. A
candidate who writes "port scan" and stops scores 1.*

(b) *(2)* Two rows differ in kind from the wall of `S0`:
- **`80 http SF 0.031`** — an **established and cleanly closed** connection with an
  identified service. Port 80 is genuinely open and was genuinely used. Amid a wall of
  failures this is the live service, and it is where the enumeration in E-E3 went.
- **`8080 - REJ 0.000`** — the target **actively refused** with a RST: closed **but
  reachable**, as opposed to silently dropped. The `S0`/`REJ` mix is telling you about the
  firewall policy — most ports are silently dropped, 8080 is not filtered at all.

*1 each. A candidate who nominates the final `22 ssh SF` row here has spotted the right
thing in the wrong question — award the mark and expect it again in (c).*

**Worth flagging in feedback:** port 22 appears **twice**, first as `S0` and later as
`ssh SF`. A sharp candidate will notice that a port cannot be both filtered and connectable
and will offer an explanation — the initial probe dropped by rate-limiting during a fast
parallel scan, or the policy changed between the two events. That observation is beyond what
the question asks and is worth a bonus point against losses elsewhere.

(c) *(2)* **T1046 — Network Service Discovery** (accept **T1595 Active Scanning** if the
candidate frames the source as external).

The row showing this did **not** stop at reconnaissance: **`10.20.0.50 → 10.20.0.10:22 ssh
SF 12.882`** — a **successfully established SSH session lasting nearly thirteen seconds**,
with the service identified and a clean close. Scanning does not produce a twelve-second
established SSH session. That is **interaction**, and it converts this from a recon event
into a possible intrusion, which changes the response entirely.

*1 for the technique, 1 for the SSH row **with the reasoning about duration and `SF`**. A
candidate who names the row but not why it is different scores 0.5.*

### E-E2 (7)

(a) *(2)* Two things are wrong with it:
1. **Counting alerts is not counting events.** The six SSH alerts are **one behaviour** — a
   single source hitting a single destination over about ten seconds. The summary inflates
   one scan into "most of the night's activity" purely because the signature fires per
   occurrence. Volume measures a rule's chattiness, not risk.
2. **It buries the lead.** The alert that occurred **once** carries **severity 1** — the
   *highest* on Suricata's scale — while the six carry severity 2. Leading with "mostly SSH
   scanning" reports the noise and omits the only high-severity item of the night.

(b) *(3)* **Threshold** — `type limit` (or `both`), tracked `by_src`. You keep the
detection: the behaviour still raises an alert, and the repeats collapse into one per window.

- **Suppression is wrong** because it removes the detection **for that source entirely** —
  creating a blind spot on `10.20.0.50`, which is currently the most interesting host in the
  dataset. You would be switching off the alarm on the one door somebody is rattling.
- **Rule modification is wrong** because the rule is **not inaccurate** — it correctly
  identified SSH scanning. Editing the signature would degrade it **everywhere in the
  estate** to solve a purely local volume problem.

*1 for choosing threshold, 1 for each correct rejection with its reason.*

(c) *(2)* Triage **the severity-1 `ET WEB_SERVER Suspicious URI` at 02:19:44** first, for
three reasons and the candidate should give at least two:
1. **Suricata severity 1 is the highest priority**, 2 is lower — the single alert is rated
   more serious than the six.
2. It is **later in time**, following the scan. Recon-then-targeted-request is an
   **escalation**, and in an active intrusion the most recent activity is the most urgent.
3. It targets **port 80** — the one port the scan proved was open and serving.

The six identical alerts are one already-understood behaviour. The answer is not the
six-occurrence alert because **count is a property of the rule, not of the risk** — which is
the whole lesson of part (b).

### E-E3 (6)

(a) *(3 — 1 each)* Three genuinely different problems:
- **`/admin/config.php.bak`** — a **backup of a configuration file left in the webroot** and
  served as text rather than executed. Config files hold database credentials, API keys, and
  secrets. This is **credential disclosure**, not merely information disclosure.
- **`/.git/config`** — the **`.git` directory is exposed**, which usually means the entire
  repository is retrievable: full source, complete history, internal hostnames, and every
  secret ever committed and later "removed". Source-code disclosure with a credential
  archive attached.
- **`/backup.zip`** — a **site or database backup archive** in the webroot: potentially the
  whole application and its data in a single download.

(b) *(1)* A **missing rule** — a detection gap, not a visibility gap and not a tuning
problem. The justification is decisive and must be present: **the traffic was captured and
logged.** Zeek produced complete `http.log` records with URI, status code, and user-agent, so
the sensor saw it and the data exists. Nothing was suppressed or thresholded, because there
is no matching signature that could have been tuned. Visibility is fine; **evaluation** is
absent.

(c) *(2)* **`status_code 200`.** A 404 would mean somebody probed and found nothing —
routine internet background noise, barely worth a ticket. **200 means the server returned
the content.** All three requests **succeeded**. This is not an attempted disclosure, it is
a **completed** one, and that changes the entire response: the incident is not "we were
scanned", it is "an unknown party holds our configuration file, our source repository, and
our backup archive". The immediate actions are **credential rotation and scope assessment**,
not rule-writing. The `curl/7.88.1` user-agent corroborates deliberate scripted retrieval
rather than a browser stumbling in.

*2 for identifying success versus attempt and drawing the consequence. A candidate who
discusses only the URIs and never mentions that they returned 200 has missed the single most
important field on the page — cap the whole question at 4.*

---

## Section 3 — Implementation on paper (25)

### E-C1 (9) — Suricata rules

(a) *(4)*

```text
alert http $EXTERNAL_NET any -> $HOME_NET any ( \
    msg:"LAB Exposed .git directory access attempt"; \
    flow:established,to_server; \
    http.uri; content:"/.git/"; nocase; \
    classtype:web-application-attack; \
    sid:1000001; rev:1;)
```

Scoring: 1 — correct header (action, protocol, direction with `$EXTERNAL_NET → $HOME_NET`);
1 — `http.uri` (or `content:"/.git/"; http_uri;` in legacy syntax) rather than a raw
payload match; 1 — `flow:established,to_server`; 1 — `msg`, `classtype`, and a `sid` **in
the local range (≥1000000)** with a `rev`. Using a sid in the reserved/ET ranges costs that
point.

(b) *(3)*

```text
alert tcp $EXTERNAL_NET any -> $HOME_NET 22 ( \
    msg:"LAB SSH repeated connection attempts from single source"; \
    flow:to_server; \
    threshold:type threshold, track by_src, count 5, seconds 60; \
    classtype:attempted-recon; \
    sid:1000002; rev:1;)
```

Scoring: 2 — `threshold:type threshold, track by_src, count 5, seconds 60`. `type limit` here
scores 1: it caps output but still alerts on the *first* attempt, which is not what was
asked. `track by_dst` scores 1 — it would aggregate across all sources and miss the
"single source" requirement. 1 — correct header and metadata.

(c) *(2)*

```text
threshold gen_id 1, sig_id 2001219, type limit, track by_src, count 1, seconds 300
```

**How it differs from (b):** `type threshold` in (b) **raises the bar for firing at all** —
no alert is produced unless five events occur in the window, so it changes *what counts as
an event* and can hide low-volume activity entirely. `type limit` in (c) **caps the output
rate** — the underlying condition still fires and you always get the **first** alert, you
just stop getting the repeats. One can make you blind to a slow attacker; the other cannot.

*1 for the syntax, 1 for the threshold-vs-limit distinction. The distinction is the graded
half.*

### E-C2 (9) — jq

(a) *(3)* Top 5 sources by total bytes originated:

```bash
jq -r 'select(.orig_bytes != null) | "\(.["id.orig_h"]) \(.orig_bytes)"' /var/log/zeek/conn.log \
  | awk '{s[$1] += $2} END {for (k in s) print s[k], k}' \
  | sort -rn | head -5
```

Pure-`jq` alternative (note `-s` is required — the log is JSON **lines**, not an array):

```bash
jq -s -r 'group_by(.["id.orig_h"])
          | map({ip: .[0]["id.orig_h"], bytes: (map(.orig_bytes // 0) | add)})
          | sort_by(-.bytes) | .[:5] | .[] | "\(.bytes)\t\(.ip)"' /var/log/zeek/conn.log
```

Scoring: 1 — correct bracket syntax for the dotted key (`.["id.orig_h"]` — a bare
`.id.orig_h` is a parse error and is the single most common mistake); 1 — summing rather
than counting; 1 — sorting descending and limiting to 5.

(b) *(3)*

```bash
jq -r 'select(.event_type=="alert" and .alert.severity==1)
       | [.timestamp, .src_ip, .alert.signature] | @tsv' /var/log/suricata/eve.json | sort
```

Scoring: 1 — filtering on **both** `event_type` and severity (omitting `event_type` means
you also match non-alert records that happen to have the field); 1 — the three fields via
`@tsv`; 1 — sorted by time.

(c) *(3)*

```bash
jq -r '[.["id.orig_h"], .["id.resp_h"], .["id.resp_p"]] | @tsv' /var/log/zeek/conn.log \
  | sort -u \
  | cut -f1,2 | uniq -c \
  | awk '$1 > 10'
```

Scoring: 2 — the **`sort -u` on the (src, dst, port) triple**, which makes each distinct port
count **once** so that retries and reconnections cannot inflate the number. Without it the
query counts connections, not ports, and the whole point is lost. 1 — the `> 10` grouping by
source-destination pair.

**Why it beats counting connections (1 of the 3 marks):** a host making 500 connections to
**one** port — a busy client, a backup job, a brute-force attempt — is indistinguishable from
a scan if you count connections. **Distinct ports** is the property that actually
characterises scanning: **breadth, not volume**. Counting connections false-positives on
every high-volume legitimate service and false-negatives on a slow scan that touches each
port exactly once.

### E-C3 (7) — Normalisation model

| Analyst field | Zeek `conn.log` | Suricata `eve.json` | YARA hit |
|---|---|---|---|
| `@timestamp` | `ts` | `timestamp` | scan time of the hit |
| `source.ip` | `id.orig_h` | `src_ip` | **none** — YARA scans a file, not a flow |
| `destination.ip` | `id.resp_h` | `dest_ip` | **none** |
| `destination.port` | `id.resp_p` | `dest_port` | **none** |
| `rule.name` | **none** — a connection record is not a detection (`note` in `notice.log`) | `alert.signature` | YARA rule name |
| `rule.id` | **none** | `alert.signature_id` | rule namespace/identifier |
| `event.severity` | **none** — `conn.log` carries no verdict | `alert.severity` | **none natively** — assign from rule metadata or policy |
| `event.dataset` | `zeek.conn` | `suricata.alert` | `yara.hit` |
| `file.name` / `file.hash` | via `files.log` (`fuid`, hashes) | `fileinfo` records | `file`, hash |

Scoring (7): 4 — a coherent table covering the six required fields across all three sources;
2 — **correctly marking the genuine absences instead of inventing values**. The two that
must be marked absent are **YARA having no network 5-tuple** (a file hit has no source IP
unless you **join back through Zeek's `files.log` on `fuid`/`uid`** — a candidate who
supplies that join earns a bonus point) and **`conn.log` having no rule identity or
severity**, because it is a record of an event, not a detection. Fabricating a severity for
Zeek connection records loses both marks.

**The mandatory field: `@timestamp`, normalised to UTC at a consistent precision.** *(1)*
Justification: the **timeline is the primary artefact** of an investigation, correlation
across sources is fundamentally a time-ordering operation, and a single source writing local
time or a different precision **silently corrupts every cross-source query** — silently
being the operative word, since the query still returns results, just wrong ones.

*Accept a **correlation identifier** (`community_id`, Zeek's `uid`) as the answer with good
justification, noting it is what makes **pivoting** possible where a timestamp only makes
**ordering** possible. Both are defensible; a candidate who names both and picks one scores
full marks.*

---

## Section 4 — Design & trade-offs (15)

### E-D1 (8)

(a) *(3 — 1 each, requiring all three columns)*

| | Gives you | Costs | If the sensor dies |
|---|---|---|---|
| **SPAN / mirror** | Software-configurable copies; no new hardware; re-point it whenever you like | Consumes switch backplane and a port; **mirroring is best-effort and drops copies first under load**; may not carry errored frames or L1 problems | **No production impact** — you simply go blind |
| **Tap** | A faithful, **lossless** line-rate copy including errors; no switch resources consumed | Hardware per link; installing it **breaks the link**, so it needs a maintenance window; usually needs an aggregator to recombine directions | **No production impact** — passive taps keep passing traffic even unpowered |
| **Inline (IPS)** | The **only** option that can **block** rather than merely record | Becomes a **single point of failure** and adds latency; a false positive becomes an **outage** | Depends on the configured fail mode — **fail-open** (traffic passes, protection lost) or **fail-closed** (link stops). That choice is a policy decision and is the question to ask |

(b) *(3)* The two strongest arguments against edge-only placement:
1. **It cannot see east-west traffic.** Lateral movement — the single most important
   post-compromise behaviour — happens entirely between internal hosts and **never crosses
   the edge sensor**. An attacker who lands by phishing and pivots across the DMZ or the
   server VLAN is completely invisible to it.
2. **It cannot attribute anything behind NAT or a proxy.** At the edge you see the NAT
   address, not the workstation, and the proxy, not the client. You get "something in the
   building did this", which is not an actionable finding.

*Also accepted for full marks: insider threat; and the assumption that the edge is the only
ingress, which ignores VPN, cloud, and malware introduced by other means that then calls out
from an unmonitored segment.*

(c) *(2)* Without decryption you still get the **TLS handshake metadata** — **SNI**,
certificate issuer/subject/validity and whether it is self-signed, **JA3/JA3S** fingerprints
of the client and server stacks, negotiated version and cipher — plus all **flow
characteristics**: who talked to whom, when, for how long, bytes in each direction, and
packet size and timing distributions. DNS usually remains visible too.

A detection that survives encryption **entirely**: **beaconing** — regular, low-variance
intervals between connections to the same destination. That is a **timing** property, and
encryption cannot hide timing. *(Also accepted: JA3 matching a known-malicious client stack;
self-signed or otherwise anomalous certificates.)*

### E-D2 (7)

(a) *(4)* At 100 GB/day against 2 TB, with logs at roughly 1% of traffic volume and flow
records smaller still:

| | Allocation | Retention | Reasoning |
|---|---:|---:|---|
| **Protocol logs (Zeek)** | ~400 GB | **~12 months** | ~1 GB/day. Highest analytic value per byte and the thing you will actually query — never let it be the constraint |
| **Flow / session records** | ~100 GB | **12 months+** | ~0.1–0.3 GB/day. Cheapest long-term memory of who talked to whom |
| **Full PCAP** | ~1.5 TB | **~10–14 days** | 100 GB/day; round the raw ~15 days down for index overhead and headroom |

*The graded shape is the **orders of magnitude**: PCAP measured in **days**, logs in
**months to a year**. A candidate who allocates evenly across the three, or who gives PCAP
months, has not internalised the volume ratio from E9(a) — cap at 2.*

(b) *(2)* At day 30 the **PCAP is gone**. You cannot extract the transferred file, read a
cleartext payload, or re-run a new signature against the original traffic.

You **can** reconstruct: who talked to whom, when, on which ports, how much data moved **in
each direction**, what names were resolved, what URIs and user-agents were used, what TLS
certificates and JA3s were seen, and which alerts fired.

**The implication:** you can establish **scope and timeline** with confidence, and you can
show **that** data left and roughly **how much** — but generally not **what** data left. For
a breach-notification decision that difference is everything: without content you must
usually reason from worst case. This is what makes retention a **business** decision rather
than a technical one, and a candidate who reaches that conclusion should get both marks.

(c) *(1)* **Stop storing bytes you cannot use.** Either a **BPF/capture filter** dropping
high-volume, low-value traffic (backup replication, storage/NFS, streaming media,
intra-cluster chatter), or **packet slicing (`snaplen`)** to headers-only for encrypted
traffic whose payload is unreadable anyway. Both cut volume by a large factor with no loss of
analytic capability. *(Also accepted: de-duplicating traffic mirrored twice, or discarding
TLS payload after the handshake.)*

---

## Section 5 — Troubleshooting narrative (10)

### E-E4 — model answer

**1. The two possibilities (2).** Either **(a) there genuinely were no alertable events** —
the environment was quiet — or **(b) the detection pipeline is broken** and events occurred
that were never detected or never recorded.

You cannot assume (a) because **the two are indistinguishable from the alert stream itself**.
An absence of alerts is the expected output of both, so silence carries **no information**
about which one you are in; a healthy sensor and a dead one produce identical dashboards.
The baseline settles it on priors: going from **200/day to 0** is a **step change**, and a
step change in a noisy metric is far more likely to be an instrumentation fault than a sudden
real change in the world.

*1 for stating both, 1 for the "silence is not evidence" argument. A candidate who treats the
quiet as plausibly good news scores 0.*

**2. Four ordered checks (4 — 1 each).**

| # | Check | Proves / disproves |
|---|---|---|
| 1 | `tcpdump -i <mon> -c 100` on the capture interface | Whether **packets are arriving at all**. If nothing: the fault is upstream — SPAN session removed, tap unpowered, cable, interface down, container interface not attached — and nothing about Suricata matters yet |
| 2 | `ip -s link show <mon>` plus Suricata's `stats.log` / `event_type: stats` (`capture.kernel_packets`, `capture.kernel_drops`) | Whether packets arrive and are **inspected**, versus arriving and being **dropped** before inspection (buffer/CPU). A rising packet counter with zero alerts is a completely different fault from a flat one |
| 3 | Suricata startup log or `suricata -T`: *"N rules successfully loaded, M failed"* | Whether the engine holds **any signatures**. A single malformed rule can abort a load, and a failed rule update can leave an empty ruleset while the process runs perfectly happily |
| 4 | `eve.json` mtime and size, the configured `outputs:` path, log rotation — and, if a SIEM sits in front of you, whether **ingest** stopped | Whether alerts are being **generated but not delivered**. "Zero alerts in the console" and "zero alerts on disk" are different problems with different owners |

*Order matters: working outward from "are packets arriving" is the graded structure. A
candidate who starts with `systemctl status suricata` has started at the least informative
link in the chain — cap at 2.*

**3. Most likely cause (2).** **The traffic stopped arriving** — the SPAN/mirror session was
removed or reconfigured during unrelated network work, or the capture interface was
detached. This is far and away the most common cause of a silent sensor, for a structural
reason worth stating: **the sensor's own configuration is under change control and the
switch's mirror session usually is not**, so it gets clobbered by work nobody thought of as
touching security. *(Second most likely, worth 1: a rule update that failed and left an empty
or unloadable ruleset.)*

**4. End-to-end verification (1).** **Generate traffic you know matches a loaded rule and
follow it the whole way through.** From a host on a monitored segment, trigger a benign test
signature — a URI matching a rule written for the purpose, or the standard test-rule
approach — then confirm, in order:
1. it appears in `tcpdump` on the capture interface,
2. it appears in Zeek's `conn.log` / `http.log`,
3. an alert appears in `eve.json`,
4. **the alert appears in the SIEM or dashboard the analyst actually looks at.**

Each of those four is a place the pipeline breaks, and only the last one is the link that
matters operationally. "The process is running" proves the least useful thing you could have
checked.

**5. The control (1).** **Alert on the absence of data** — a detection heartbeat. Either a
monitoring rule that fires when the sensor's event rate falls below a floor for N minutes (a
dead-man's switch on `stats.log` packet counters or on SIEM ingest volume), or a **synthetic
canary**: a scheduled job that generates known-matching traffic every few minutes and raises
an alert when the corresponding detection fails to appear. The principle is the one this
whole question exists to teach — **monitor the monitoring, and treat silence as a condition
to alert on rather than a state to enjoy.**

---

## Remediation table

| Question | Topic | Lab |
|---|---|---|
| E1, E-E1, E-C2 | Zeek logs, `conn_state`, jq analysis | `labs/soc-zeek-analysis`, `labs/soc-dmz-foundation` |
| E2, E3, E6, E-E2, E-C1 | Suricata alerts, EVE JSON, tuning, rule writing | `labs/soc-suricata-ids` |
| E4 | YARA and file extraction | `labs/soc-yara-file-pipeline` |
| E5, E-C3 | SIEM normalisation and field mapping | `labs/soc-elk-ingest`, `labs/soc-kibana-hvt-dashboard` |
| E7, E-E3 | ATT&CK mapping and detection gaps | `labs/soc-adversary-simulation` |
| E8 | IOC types, operationalisation, aging | `labs/soc-threat-intel-misp` |
| E9, E-D2 | PCAP, flow, log volume and retention | `labs/soc-arkime-pcap`, `labs/packet-analysis-basics` |
| E10 | Observables, containment, timeline | `labs/soc-ir-case-management` |
| E-D1 | Sensor placement and visibility | `labs/soc-dmz-foundation`, `labs/network-assurance`, `labs/enterprise-dmz` |
| E-E4 | Silent sensor / monitoring the monitoring | `labs/soc-suricata-ids`, `labs/network-assurance` |
