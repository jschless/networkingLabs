FROM debian@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        conntrack=1:1.4.7-1+b2 \
        curl \
        dnsutils \
        dnsmasq=2.90-4~deb12u2 \
        iproute2 \
        iputils-ping \
        jq \
        libnginx-mod-http-modsecurity=1.0.3-1+b2 \
        modsecurity-crs=3.3.4-1+deb12u3 \
        netcat-openbsd \
        nftables=1.0.6-2+deb12u2 \
        nginx=1.22.1-9+deb12u9 \
        openssl \
        procps \
        python3 \
        rsyslog=8.2302.0-1+deb12u1 \
        squid=5.7-2+deb12u6 \
        tcpdump \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
