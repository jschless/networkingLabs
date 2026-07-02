# FRR 8.4 — pinned by digest. Upstream stopped pushing frrouting/frr:latest in
# Nov 2022, so the tag is frozen at 8.4; the digest makes that explicit and
# immune to a surprise future push. All lab configs and docs in this repo
# assume FRR 8.4 syntax (see CLAUDE.md "FRR version and syntax") — do not bump
# this without re-validating the labs.
FROM frrouting/frr:latest@sha256:990e83490108b686fd6df3b1cafa6bdbb2714acb00eedb9a89693946f46f45ce

RUN apk add --no-cache tcpdump tshark
