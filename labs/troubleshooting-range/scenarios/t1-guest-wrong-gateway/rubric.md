# Proctor rubric — TR-102 (confidential)

**Root cause:** `guest1` has an incorrect default gateway. **Pass:** 70/100 and `verify.sh` green. **Time:** 15 minutes.

Score local addressing/default-route inspection (35), comparison with the documented guest gateway (25), minimal route correction (20), and client-side verification (20). Deduct 15 for changing switch/routing state without proving the endpoint fault; no verification caps at 69.
