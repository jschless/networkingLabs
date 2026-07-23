FROM debian:12.12-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ethtool \
       iperf3 \
       iproute2 \
       iputils-ping \
       openvswitch-switch \
       tcpdump \
    && rm -rf /var/lib/apt/lists/*

COPY configs/common/entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
