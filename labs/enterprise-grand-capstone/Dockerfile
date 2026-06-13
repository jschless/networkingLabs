# gcap-node:local — the Linux building block for the grand capstone.
#
# One image serves both roles:
#   * access switches  — hostapd (802.1X authenticator) + nftables + bridge tools
#   * endpoints        — wpa_supplicant (802.1X supplicant) + dhclient + krb5/dns
#
# Built by ./gcap.sh build (or docker build -t gcap-node:local .)
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    hostapd \
    wpasupplicant \
    isc-dhcp-client \
    nftables \
    bridge-utils \
    iproute2 \
    iputils-ping \
    tcpdump \
    net-tools \
    procps \
    dnsutils \
    krb5-user \
    curl \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
