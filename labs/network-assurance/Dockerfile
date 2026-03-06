FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    frr \
    snmpd \
    snmp \
    rsyslog \
    tcpdump \
    softflowd \
    nfdump \
    iproute2 \
    iputils-ping \
    net-tools \
    procps \
    curl \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
