# Stateful HA firewall node: keepalived (VRRP for the VIPs) + conntrackd
# (connection-tracking state sync) + nftables (the stateful ruleset). netbase
# ships /etc/protocols, without which conntrackd's `Protocol Accept { TCP }`
# filter can't resolve the protocol name. iperf3/ncat drive the long-lived
# flow the lab is built around.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    keepalived \
    conntrackd \
    conntrack \
    nftables \
    netbase \
    iproute2 \
    iputils-ping \
    tcpdump \
    ncat \
    iperf3 \
    netcat-openbsd \
    procps \
    curl \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
