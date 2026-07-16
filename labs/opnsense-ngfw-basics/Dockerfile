FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    dnsutils \
    dnsmasq \
    iptables \
    iproute2 \
    iputils-ping \
    netcat-openbsd \
    openssl \
    procps \
    socat \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
