FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90

ARG SIPP_VERSION=3.7.7
ARG SIPP_SHA256=8e8ecdbe923bf608c844038adfa35c8595400c4629d629f00d51539ac24cdfef

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      asterisk=1:20.6.0~dfsg+~cs6.13.40431414-2build5 \
      ca-certificates=20260601~24.04.1 \
      chrony=4.5-1ubuntu4.2 \
      conntrack=1:1.4.8-1ubuntu1 \
      curl=8.5.0-2ubuntu10.11 \
      bind9-dnsutils=1:9.18.39-0ubuntu0.24.04.5 \
      dnsmasq=2.90-2ubuntu0.4 \
      iproute2=6.1.0-1ubuntu6.4 \
      iputils-ping=3:20240117-1ubuntu0.1 \
      iperf3=3.16-1build2 \
      isc-dhcp-client=4.4.3-P1-4ubuntu2 \
      jq=1.7.1-3ubuntu0.24.04.2 \
      netcat-openbsd=1.226-1ubuntu2 \
      nftables=1.0.9-1ubuntu0.1 \
      procps=2:4.0.4-4ubuntu3.2 \
      python3=3.12.3-0ubuntu2.1 \
      sox=14.4.2+git20190427-4build4 \
      tcpdump=4.99.4-3ubuntu4.24.04.1 \
    && curl -fsSL \
      "https://github.com/SIPp/sipp/releases/download/v${SIPP_VERSION}/sipp" \
      -o /usr/local/bin/sipp \
    && echo "${SIPP_SHA256}  /usr/local/bin/sipp" | sha256sum -c - \
    && chmod 0755 /usr/local/bin/sipp \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/voice /var/log/asterisk /var/run/asterisk \
    && python3 -c "from pathlib import Path; Path('/opt/voice/pcmu.raw').write_bytes(bytes((i % 251 for i in range(8000))))"

CMD ["sleep", "infinity"]
