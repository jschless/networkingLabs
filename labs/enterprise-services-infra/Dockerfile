FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    dnsmasq \
    isc-dhcp-client \
    chrony \
    rsyslog \
    iproute2 \
    iputils-ping \
    curl \
    jq \
    procps \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
