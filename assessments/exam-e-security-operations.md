# Exam E — Security Operations (SOC)

**Time:** 1.5 hours · **Total:** 100 points · **Closed book, no CLI**

Covers `labs/soc-*`: DMZ visibility, Zeek protocol logs, Suricata IDS, YARA, SIEM ingest,
dashboards, packet search, adversary simulation, threat intel, and incident response
workflow.

This exam assumes you can read JSON and think in fields. Where a question asks for a query,
write it — `jq` and Suricata rule syntax are both graded for correctness.

---

## Section 1 — Concepts & mechanisms (30 points)

Ten questions, 3 points each.

**E1.** Zeek is not an IDS. State what it actually produces and how that differs from what
Suricata produces. Then name four fields in `conn.log` and explain what the `conn_state`
field is for, giving the value you would expect from a host that sent SYNs to a hundred
closed ports.

**E2.** Distinguish a **Suricata alert** from a **Zeek notice**. What triggers each, what
does each assert, and which one is more likely to be right about *whether something bad
happened* versus *whether a pattern matched*?

**E3.** Suricata's EVE JSON is one stream carrying many record types. Name four
`event_type` values you would expect to see, and list the fields you need from an `alert`
record to triage it without opening anything else.

**E4.** YARA. (a) What does a YARA rule match against, and what are the two required parts
of a rule body? (b) Where does YARA sit in the `soc-yara-file-pipeline` design — what has
to happen before YARA can run at all? (c) Give one detection YARA is good at that a network
signature is bad at, and one the reverse.

**E5.** SIEM normalisation. Zeek writes `id.orig_h`, Suricata writes `src_ip`, and YARA
writes `file`. Explain what normalisation does to these, why an analyst cannot work without
it, and what specifically becomes impossible if you skip it.

**E6.** Detection tuning. Define **threshold**, **suppression**, and **rule modification**,
and say when each is the right response to a noisy signature. Then name the one of the three
that is most dangerous and explain the failure mode.

**E7.** ATT&CK. Identify **T1046**, **T1595**, and **T1110**, and say what each one looks
like in `conn.log`. Then define what a **detection gap** means in the
`soc-adversary-simulation` sense — be precise, because "we have no rule for it" is only one
of the ways to have a gap.

**E8.** Threat intel. Rank these IOC types by how safely they can be operationalised
directly into a blocking rule: **file hash**, **IP address**, **domain name**, **TLS
fingerprint (JA3)**. Justify the ranking, and explain what "IOC aging" means and why it
matters more for some types than others.

**E9.** Packet capture. (a) Give the storage trade-off between full packet capture, flow
records, and protocol logs — approximate relative volume for the same traffic. (b) Name two
questions that **only** full packet capture can answer. (c) Name one question that full
packet capture **cannot** answer in a modern network, and say why.

**E10.** Incident response. Define **observable**, **containment**, and **eradication**, and
explain why a timeline is the primary artefact of a case rather than a nice-to-have. Then
state one action that feels like containment and actually destroys evidence.

---

## Section 2 — Evidence reading (20 points)

### E-E1 (7 points)

From `sensor`, filtering `conn.log`:

```text
sensor# jq -r '[.["id.orig_h"],.["id.resp_h"],.["id.resp_p"],.service,.conn_state,.duration] | @tsv' /var/log/zeek/conn.log | head -12
10.20.0.50   10.20.0.10   21     -      S0    -
10.20.0.50   10.20.0.10   22     -      S0    -
10.20.0.50   10.20.0.10   23     -      S0    -
10.20.0.50   10.20.0.10   25     -      S0    -
10.20.0.50   10.20.0.10   80     http   SF    0.031
10.20.0.50   10.20.0.10   110    -      S0    -
10.20.0.50   10.20.0.10   143    -      S0    -
10.20.0.50   10.20.0.10   443    -      S0    -
10.20.0.50   10.20.0.10   445    -      S0    -
10.20.0.50   10.20.0.10   3306   -      S0    -
10.20.0.50   10.20.0.10   8080   -      REJ   0.000
10.20.0.50   10.20.0.10   22     ssh    SF    12.882
```

(a) State what happened, and cite the specific evidence — do not just name the technique.
(3 pts)
(b) Two rows differ in kind from the rest. Identify them and explain why each is
significant. (2 pts)
(c) Map this to an ATT&CK technique, and name the **one** row that suggests the activity did
not stop at reconnaissance. (2 pts)

### E-E2 (7 points)

From `sensor`, Suricata EVE:

```text
sensor# jq -r 'select(.event_type=="alert") | [.timestamp,.src_ip,.dest_ip,.dest_port,.alert.signature,.alert.severity] | @tsv' /var/log/suricata/eve.json
2024-03-11T02:14:07  10.20.0.50  10.20.0.10  22  ET SCAN Potential SSH Scan            2
2024-03-11T02:14:09  10.20.0.50  10.20.0.10  22  ET SCAN Potential SSH Scan            2
2024-03-11T02:14:11  10.20.0.50  10.20.0.10  22  ET SCAN Potential SSH Scan            2
2024-03-11T02:14:13  10.20.0.50  10.20.0.10  22  ET SCAN Potential SSH Scan            2
2024-03-11T02:14:15  10.20.0.50  10.20.0.10  22  ET SCAN Potential SSH Scan            2
2024-03-11T02:14:17  10.20.0.50  10.20.0.10  22  ET SCAN Potential SSH Scan            2
2024-03-11T02:19:44  10.20.0.50  10.20.0.10  80  ET WEB_SERVER Suspicious URI          1
```

(a) An analyst reports "seven alerts overnight, mostly SSH scanning". Explain what is wrong
with that summary as an assessment of the night's activity. (2 pts)
(b) You want to reduce the SSH noise without losing the ability to detect the behaviour.
State which tuning mechanism you choose, and why the other two are wrong here. (3 pts)
(c) Which of these seven alerts would you triage first, and why is the answer not the one
with six occurrences? (2 pts)

### E-E3 (6 points)

Zeek `http.log` for the same period contains:

```text
sensor# jq -r '[.ts,.["id.orig_h"],.host,.uri,.status_code,.user_agent] | @tsv' /var/log/zeek/http.log
...  10.20.0.50  10.20.0.10  /admin/config.php.bak   200  curl/7.88.1
...  10.20.0.50  10.20.0.10  /.git/config            200  curl/7.88.1
...  10.20.0.50  10.20.0.10  /backup.zip             200  curl/7.88.1
```

Suricata produced **no alert** for any of these three requests.

(a) State the security significance of each of the three requests — they are not the same
problem. (3 pts)
(b) This is a detection gap. Classify it: is it a missing rule, a visibility gap, or a
tuning problem? Justify. (1 pt)
(c) The `status_code` field is the most alarming thing on the page. Explain. (2 pts)

---

## Section 3 — Implementation on paper (25 points)

### E-C1 (9 points) — Suricata rules

Write two rules and one tuning entry:

(a) A rule that alerts on an HTTP request whose URI contains `/.git/` from any external
source to your web server, with a sensible `msg`, `classtype`, `sid`, and `rev`. (4 pts)
(b) A rule that alerts only when a single source makes **five or more** connection attempts
to TCP/22 within **60 seconds**, rather than alerting on each one. (3 pts)
(c) A `threshold.config` entry that limits an existing noisy signature (`sid:2001219`) to at
most one alert per source per five minutes. State how (c) differs in effect from (b).
(2 pts)

### E-C2 (9 points) — jq

Write single `jq` (or `jq` + shell) pipelines against the lab's files:

(a) From `conn.log`, list the top 5 source IPs by **total bytes originated**. (3 pts)
(b) From `eve.json`, list every alert of severity 1, showing timestamp, source, signature —
sorted by time. (3 pts)
(c) From `conn.log`, list every source IP that contacted **more than 10 distinct destination
ports** on a single destination host. Explain in one line why this query is a better scan
detector than counting connections. (3 pts)

### E-C3 (7 points) — SIEM normalisation model

Design the normalised field mapping that `soc-elk-ingest` asks for. Produce a table mapping
the three sources into common analyst fields, covering at minimum: event time, source host,
destination host, destination port, the detection/rule identity, and a severity.

State for each row where the value comes from in each source, and mark any cell where a
source genuinely **has no equivalent** — do not invent one. Then name the single field you
would make mandatory across all three indexes and justify it.

---

## Section 4 — Design & trade-offs (15 points)

### E-D1 (8 points)

You are placing sensors for the `soc-dmz-foundation` environment.

(a) Compare **SPAN/mirror**, **network tap**, and **inline** deployment: what each gives
you, what each costs, and the failure behaviour of each when the sensor dies. (3 pts)
(b) A colleague proposes one sensor at the internet edge, arguing that all attacks come from
outside. Give the two strongest arguments against, referring to what that placement cannot
see. (3 pts)
(c) Most of the traffic you want to inspect is TLS-encrypted. State what you can still
derive without decryption, and name one detection that survives encryption entirely.
(2 pts)

### E-D2 (7 points)

Design retention for a small SOC with 2 TB of usable storage and roughly 100 GB/day of
traffic on the monitored segments.

(a) Allocate the storage across full PCAP, flow/session records, and protocol logs, with
approximate retention windows for each. Show your reasoning. (4 pts)
(b) An incident is discovered 30 days after it happened. State what you can and cannot
reconstruct under your design, and what that implies for the investigation. (2 pts)
(c) Name one change to the capture configuration — not the storage budget — that
substantially extends useful PCAP retention. (1 pt)

---

## Section 5 — Troubleshooting narrative (10 points)

### E-E4

**Situation:** The IDS has produced **zero alerts in the last 12 hours**. The Suricata
process is running, the host is up, and disk space is fine. Yesterday it averaged 200 alerts
a day.

This is a monitoring failure, and it is the most dangerous kind because it looks like good
news.

1. **State the two mutually exclusive top-level possibilities** and say why you cannot
   assume the benign one. (2 pts)
2. **Four checks**, ordered, each with the specific thing it proves or disproves. Work from
   "are packets arriving" outward. (4 pts)
3. **The single most likely cause** in a lab or production environment where nothing about
   Suricata itself was changed. (2 pts)
4. **A verification that proves the detection pipeline end to end** — not just that the
   process is running. Be specific about what you would generate and what you would then go
   and look at. (1 pt)
5. **A control** that would have told you about this within minutes instead of twelve hours.
   (1 pt)

---

*End of Exam E. Key: [`answer-keys/exam-e-key.md`](answer-keys/exam-e-key.md).*
