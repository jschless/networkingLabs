# Proctor rubric — TR-203 (confidential)

**Root cause:** acc2 has a static Null0 route for `198.18.0.0/24`, overriding the learned route. **Pass:** 70/100 and `verify.sh` green. **Time:** 35 minutes.

Score scope comparison (20), forwarding-table evidence (35), minimal static-route removal (25), and guest-side verification (20). Broad routing changes or no endpoint verification cap the score at 69.
