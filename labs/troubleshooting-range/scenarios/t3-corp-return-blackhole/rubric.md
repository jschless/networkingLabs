# Proctor rubric — TR-303 (confidential)

**Root cause:** core1 has a static Null0 route for the corporate subnet, blackholing replies from the services block while unrelated corporate-to-branch traffic continues. **Pass:** 70/100 and `verify.sh` green. **Time:** 60 minutes.

Score cross-layer scope separation (25), bidirectional path/route evidence (35), minimal static-route removal (20), and corporate DNS plus TCP verification (20). Client workarounds or service restart without return-path proof cap at 69.
