FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    freeradius \
    freeradius-utils \
    wpasupplicant \
    openssl \
    iproute2 \
    iputils-ping \
    tcpdump \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
