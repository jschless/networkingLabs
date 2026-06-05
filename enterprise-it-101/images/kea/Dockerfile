FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    kea-dhcp4-server \
    kea-dhcp-ddns-server \
    kea-common \
    bind9-dnsutils \
    dnsutils \
    iproute2 \
    iputils-ping \
    tcpdump \
    vim \
    less \
    && rm -rf /var/lib/apt/lists/*

# Kea writes leases + sockets here.
RUN mkdir -p /var/lib/kea /var/run/kea /var/log/kea /etc/kea

# Convenience helpers to (re)start / stop the Kea daemons detached with logs.
COPY kea-start /usr/local/bin/kea-start
COPY kea-stop  /usr/local/bin/kea-stop
RUN chmod +x /usr/local/bin/kea-start /usr/local/bin/kea-stop

# The container idles; the student writes /etc/kea/kea-dhcp4.conf and
# kea-dhcp-ddns.conf and starts the daemons by hand (see the lab README).
CMD ["sleep", "infinity"]
