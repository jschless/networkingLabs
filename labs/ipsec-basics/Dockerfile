FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    strongswan \
    iproute2 \
    iputils-ping \
    tcpdump \
    iptables \
    vim \
    procps \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
