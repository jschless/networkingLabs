FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    inotify-tools \
    iproute2 \
    iputils-ping \
    jq \
    netcat-openbsd \
    procps \
    python3 \
    suricata \
    tcpdump \
    tshark \
    yara \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
