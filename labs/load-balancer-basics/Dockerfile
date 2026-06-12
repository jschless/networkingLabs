FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    haproxy \
    nginx-light \
    nftables \
    iproute2 \
    iputils-ping \
    netcat-openbsd \
    tcpdump \
    net-tools \
    procps \
    curl \
    socat \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
