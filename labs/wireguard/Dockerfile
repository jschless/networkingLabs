FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools \
    iproute2 \
    iputils-ping \
    iptables \
    net-tools \
    netcat-openbsd \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash", "-c", "while true; do sleep 3600; done"]
