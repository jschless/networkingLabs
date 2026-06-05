FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bind9 \
    bind9-utils \
    bind9-dnsutils \
    dnsutils \
    vim \
    less \
    iproute2 \
    iputils-ping \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

# Generate an rndc control key so the student can apply config changes with
# `rndc reconfig` / `rndc reload` instead of restarting the (PID 1) daemon.
RUN rndc-confgen -a -A hmac-sha256 -c /etc/bind/rndc.key \
    && chown root:bind /etc/bind/rndc.key \
    && chmod 0640 /etc/bind/rndc.key

# Baseline config: a *recursion-off* resolver that does nothing useful yet.
# Building it into a real enterprise resolver (recursion, conditional
# forwarding, views, reverse zones) is the lab.
COPY named.conf /etc/bind/named.conf
COPY named.conf.options /etc/bind/named.conf.options
COPY named.conf.local /etc/bind/named.conf.local

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 53/tcp 53/udp 953/tcp

CMD ["/usr/local/bin/entrypoint.sh"]
