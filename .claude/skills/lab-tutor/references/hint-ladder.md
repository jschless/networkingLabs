# The Hint Ladder

A stuck student gets ONE rung at a time. Offer a rung, then stop and let them work. Climb
only when they've engaged with the rung below and are still stuck. The art is starting as
high (as Socratic) as the student can handle and resisting the urge to jump to the bottom.

---

## Rung 1 — Orient

Find out where they actually are before diagnosing anything.

- "Which step of the README are you on?"
- "What did you expect to happen, and what did you actually see?"
- "What have you already tried?"

Half of all "it's broken" reports resolve here, because the student realizes they skipped a
step or misread the goal. Do not skip this rung — it's tempting to dive into the config you
already know is wrong, but the student learns to *self-orient* by being asked to.

## Rung 2 — Point at the evidence

Name the one command that will make the problem visible, and ask them to run it and read it
back. Do **not** interpret the output for them.

- "Run `show ip bgp summary` on r2 — what state are the sessions in?"
- "Check `show ip route` — is the prefix you're expecting actually there?"

This teaches the diagnostic reflex: *which* command answers *which* question.

## Rung 3 — Narrow the search

If they've read the output but don't see the issue, direct their attention to the specific
field — without stating the conclusion.

- "Look at the NEXT_HOP column. Is that address one this router can actually reach?"
- "Compare the area number on this interface to its neighbor's."

You're drawing a circle around the answer, not writing it inside the circle.

## Rung 4 — Conceptual nudge

Explain the underlying mechanism in the abstract, so they can apply it to what they're
seeing. Still no lab-specific verdict.

- "Remember: iBGP doesn't rewrite the next-hop by default. So whatever the eBGP edge router
  learned, the iBGP peer sees that same next-hop — even if it can't reach it."
- "OSPF only forms adjacency when several parameters match exactly. Area is one. There are
  three or four others."

Now the student has the principle and the evidence; the connection is theirs to make.

## Rung 5 — Targeted hint

Name the feature or area at fault — but not the literal fix.

- "This is a next-hop-reachability problem. The fix lives in how r2 advertises routes to its
  iBGP peer."
- "The mismatch is in the OSPF interface configuration on one of these two routers."

## Rung 6 — Walk the fix together

Only after genuine effort. Co-construct it; the student types every line and says what it
does. Never paste a finished block.

- "Okay — go into `router bgp 65002`. What command tells r2 to set itself as the next-hop
  for its iBGP peer? …Right, `neighbor <peer> next-hop-self`. Type it. Now re-run the
  verification — what changed?"

End with the loop closed: have them state *why* it worked, and connect it to the concept
from rung 4.

---

## Pacing rules

- One rung per message. Resist stacking.
- Re-assess after each rung: a student who gets it at rung 3 should not be marched through
  4–6.
- Frustration after real effort earns a faster climb — but never skip the student's final
  reasoning step. The keystroke is worthless without the "aha."
- After the fix, always enrich (the "why," a counterfactual, a related lab). The ladder ends
  in understanding, not just a working `ping`.
