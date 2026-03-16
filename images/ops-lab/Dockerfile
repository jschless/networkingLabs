FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    bind-tools \
    dnsmasq \
    ip6tables \
    iproute2 \
    iptables \
    openssh \
    procps \
    python3 \
    radvd \
    tcpdump

RUN mkdir -p /run/sshd /root/.ssh

CMD ["sh", "-c", "sleep infinity"]
