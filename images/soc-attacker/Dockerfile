FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    hydra \
    iproute2 \
    iputils-ping \
    jq \
    netcat-openbsd \
    nmap \
    procps \
    python3 \
    tcpdump \
    tshark \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
