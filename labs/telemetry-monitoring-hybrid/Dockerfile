FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    frr \
    snmpd \
    snmp \
    iproute2 \
    iputils-ping \
    iperf3 \
    curl \
    jq \
    tcpdump \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
