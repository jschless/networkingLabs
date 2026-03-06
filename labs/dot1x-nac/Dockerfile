FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    hostapd \
    wpasupplicant \
    freeradius \
    freeradius-utils \
    openssl \
    ebtables \
    bridge-utils \
    iproute2 \
    iputils-ping \
    tcpdump \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
