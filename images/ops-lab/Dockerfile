FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc

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
