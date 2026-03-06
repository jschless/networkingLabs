FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 \
    wpasupplicant \
    openssl \
    tcpdump \
    iputils-ping \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
