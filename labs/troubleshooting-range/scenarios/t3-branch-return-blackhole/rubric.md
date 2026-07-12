# Proctor rubric — TR-304 (confidential)

**Root cause:** core1 has a static Null0 route for the branch subnet. Branch requests reach the services block, but replies are dropped at the core while branch-to-corporate traffic can still work. **Pass:** 70/100 and `verify.sh` green. **Time:** 60 minutes.

Score comparison of the working and failing paths (25), bidirectional route evidence (35), minimal removal of the masking route (20), and branch-client verification (20). Static client workarounds or changing services without return-path proof cap at 69.
