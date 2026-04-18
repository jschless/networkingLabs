FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    iproute2 \
    iptables \
    iputils-ping \
    jq \
    netcat-openbsd \
    openssh-client \
    openssh-server \
    procps \
    python3 \
    tcpdump \
    tshark \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd

CMD ["sleep", "infinity"]
