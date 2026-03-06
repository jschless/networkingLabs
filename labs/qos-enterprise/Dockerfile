FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 iperf3 iputils-ping tcpdump net-tools procps ncat \
    && rm -rf /var/lib/apt/lists/*
CMD ["sleep", "infinity"]
