FROM debian:12.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl iproute2 iputils-ping nftables openssl \
    procps python3 tcpdump wireguard-tools && \
    rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash", "-c", "while true; do sleep 3600; done"]
