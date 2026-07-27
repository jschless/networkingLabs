# Written Assessments

A written assessment bank covering the three tracks in this repo. These are **paper tests**, not
labs: no containers, no CLI, no internet. They exist to check whether the understanding
behind a completed lab actually stuck — the part a green `./scripts/lab.sh check` cannot
tell you.

The bank has two layers:

- [Topic quizzes](quizzes/README.md) are short, formative checks taken after a small group
  of related labs.
- The five exams below are broad, cumulative assessments taken after a study path or
  major track.

Quiz results are intentionally more diagnostic than exam results: a weak OSPF score, for
example, points directly back to the OSPF labs instead of being hidden inside a passing
Core Routing & Switching score.

## Why a written test at all

Finishing a lab proves you produced a working configuration. It does not prove you could
produce it again on a different topology, explain why it works, or recognise the same
failure with different symptoms. Every question here is written against a lab in this
repo, but almost none of them can be answered by recalling the lab's solution toggle —
they change the topology, invert the question, or hand you an output and ask what
happened.

## The five exams

| Exam | Covers | Labs behind it | Time |
|---|---|---|---:|
| [A — Core Routing & Switching](exam-a-core-routing-switching.md) | OSPF, EIGRP, IS-IS, BGP, route control, Layer 2, lab harness | OSPF/EIGRP/BGP/IS-IS/route-control/layer2 tracks | 2 h |
| [B — Advanced Infrastructure](exam-b-advanced-infrastructure.md) | MPLS/SR/L3VPN, VXLAN-EVPN, tunnels & VPN, high availability | MPLS-SP, data-center, tunnels-vpn, HA tracks | 2 h |
| [C — Enterprise, Security & Operations](exam-c-enterprise-security-operations.md) | Campus/DMZ/WAN design, edge security, NAT, QoS, observability, automation | enterprise, security, operations tracks | 2 h |
| [D — Enterprise IT 101](exam-d-enterprise-it-101.md) | AD, Kerberos, PKI, DNS, DHCP, SSO, RADIUS, mail, backup | `enterprise-it-101/labs/01`–`16` | 1.5 h |
| [E — Security Operations (SOC)](exam-e-security-operations.md) | Zeek, Suricata, YARA, SIEM, threat intel, IR workflow | `labs/soc-*` | 1.5 h |

Each exam is scored out of 100 and uses the same five-section shape:

| Section | Points | What it measures |
|---|---:|---|
| 1 — Concepts & mechanisms | 30 | Do you know *why* the protocol behaves that way |
| 2 — Evidence reading | 20 | Can you diagnose from an output you did not generate |
| 3 — Implementation on paper | 25 | Can you write correct configuration without a CLI to autocomplete for you |
| 4 — Design & trade-offs | 15 | Can you choose between two defensible options and defend the choice |
| 5 — Troubleshooting narrative | 10 | Can you run a disciplined method, not a guess-and-check loop |

Sections 3 and 5 are where implementation ability gets tested as directly as paper allows.
Section 3 asks for real syntax on the real platform the lab uses — graded on correctness,
not on prettiness. Section 5 asks for the method: hypothesis, the command that would
confirm or kill it, the output you expect in each case, the minimal fix, and the
verification from the affected user's perspective. A right answer with no method scores
about half; a wrong answer with a sound method scores more than you would expect.

## Answer keys

Keys live in [`answer-keys/`](answer-keys/) — one per exam, with per-question grading
notes, partial-credit guidance, and a **question → lab** remediation table at the end. If
you are taking an exam, do not open the key first; the lab list at the bottom of each key
is the actually useful part afterwards.

Keys are deliberately outside `docs/`, so `mkdocs build` does not publish them to the
site.

## Administering

**Self-study.** Take one exam closed-book in a single sitting. Mark it against the key,
then re-run every lab in the remediation table for questions you lost more than half the
points on. The remediation table is the point of the exercise.

**Proctored.** Same conventions as the [troubleshooting range](../labs/troubleshooting-range/ASSESSMENT.md):
closed-book, no shell, published time band, and the red-flag caps apply to Section 5 —
an answer that masks a symptom rather than repairing the cause is capped regardless of
raw points, even if the symptom would genuinely disappear.

Suggested qualification bands:

| Score | Band | Reading |
|---:|---|---|
| ≥ 85 | Pass with distinction | Ready for the capstones and the proctored ranges in this domain |
| 70–84 | Pass | Solid; work the remediation table before moving to the next track |
| 55–69 | Marginal | Re-run the labs behind your weakest section, then retake |
| < 55 | Not yet | Re-run the track from the start of its study path |

## A note on the output blocks

The `show` output in Section 2 of each exam is **hand-built to be diagnostic, not captured
verbatim from a running lab**. It is formatted to match the platform closely enough that
the reasoning transfers, but do not treat a byte of it as a reference for exact field
layout — deploy the lab for that. Where a question turns on a specific number, the number
is internally consistent and the arithmetic works out.

## Extending the bank

Questions are grounded in labs that exist. If you add a lab, add questions the same way
the existing ones are built:

- **Change the topology.** Ask the question on three routers when the lab had four.
- **Invert it.** The lab configures the feature; the exam gives the symptom of the
  feature being half-configured.
- **Ask for the mechanism, not the command.** "Which command" is a lookup; "which field
  in which packet made this fail" is knowledge.
- Add the new question to the remediation table in the answer key, or it will not help
  anyone who gets it wrong.

After adding or changing a topic quiz, run:

```bash
python3 scripts/validate-quizzes.py
python3 scripts/test-validate-quizzes.py
```

The validator checks quiz/key pairing, point totals, catalog time and point metadata,
remediation lab references, local links, and trailing whitespace. To audit how much of
the lab catalog is directly named by quiz remediation tables, also run:

```bash
python3 scripts/validate-quizzes.py --coverage
```

Uncovered labs are reported for review rather than treated as failures because capstones,
debug variants, shared fixtures, and newly developing labs do not always need their own
topic quiz.
