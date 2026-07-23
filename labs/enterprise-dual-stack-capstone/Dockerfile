FROM debian:12.12-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bind9 bind9utils curl dnsutils iproute2 iputils-ping kea netcat-openbsd \
      nftables python3 tcpdump \
 && rm -rf /var/lib/apt/lists/*

CMD ["bash"]
