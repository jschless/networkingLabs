# FRR 8.4 — all lab configs and docs in this repo assume FRR 8.4 syntax (see
# CLAUDE.md "FRR version and syntax"); do not bump without re-validating labs.
# quay.io publishes multi-arch (amd64+arm64) builds; Docker Hub frrouting/frr
# stopped updating in Nov 2022 and is amd64-only.
FROM quay.io/frrouting/frr:8.4.2

# openssl: the dmvpn-phase3-ipsec-capstone CA node issues router certificates
RUN apk add --no-cache tcpdump tshark openssl
