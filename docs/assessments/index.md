---
title: Written Assessments
---

{%
  include-markdown "../../assessments/README.md"
  end="## Answer keys"
  rewrite-relative-urls=false
%}

## Answer keys

Keys are deliberately kept out of this site so that a search for a question does not
surface its answer. They live in the repository under
[`assessments/answer-keys/`](https://github.com/jschless/networkingLabs/tree/main/assessments/answer-keys),
one per exam and one per quiz, with per-question grading notes, partial-credit guidance,
and a **question → lab** remediation table at the end. If you are taking an exam, do not
open the key first; the lab list at the bottom of each key is the actually useful part
afterwards.

## Administering

**Self-study.** Take one exam closed-book in a single sitting. Mark it against the key,
then re-run every lab in the remediation table for questions you lost more than half the
points on. The remediation table is the point of the exercise.

**Proctored.** Same conventions as the
[Enterprise Troubleshooting Range](../tracks/troubleshooting/troubleshooting-range.md)
(whose [assessment protocol](https://github.com/jschless/networkingLabs/blob/main/labs/troubleshooting-range/ASSESSMENT.md)
is in the repository): closed-book, no shell, published time band, and the red-flag caps
apply to Section 5 — an answer that masks a symptom rather than repairing the cause is
capped regardless of raw points, even if the symptom would genuinely disappear.

Suggested qualification bands:

| Score | Band | Reading |
|---:|---|---|
| ≥ 85 | Pass with distinction | Ready for the capstones and the proctored ranges in this domain |
| 70–84 | Pass | Solid; work the remediation table before moving to the next track |
| 55–69 | Marginal | Re-run the labs behind your weakest section, then retake |
| < 55 | Not yet | Re-run the track from the start of its study path |

{%
  include-markdown "../../assessments/README.md"
  start="## A note on the output blocks"
  end="## Extending the bank"
  rewrite-relative-urls=false
%}

## Extending the bank

Adding questions, and the validators that keep the bank consistent, are covered in
[`assessments/README.md`](https://github.com/jschless/networkingLabs/blob/main/assessments/README.md)
in the repository.
