FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

# Package candidates recorded 2026-08-24. Refresh these as one tested set;
# repeat the clean deploy, break, repair, and capture workflow in VALIDATION.md.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2=6.1.0-3 \
        iptables=1.8.9-2 \
        iputils-ping=3:20221126-1+deb12u1 \
        procps=2:4.0.2-3 \
        strongswan=5.9.8-5+deb12u5 \
        tcpdump=4.99.3-1 \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
