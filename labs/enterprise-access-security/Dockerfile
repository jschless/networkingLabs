FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    dnsmasq \
    isc-dhcp-client \
    iproute2 \
    iputils-ping \
    arping \
    tcpdump \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
