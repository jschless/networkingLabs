FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates curl iproute2 iputils-ping jq netcat-openbsd \
       nftables openssh-client openssh-server sshpass python3 python3-venv \
       suricata tcpdump ulogd2 \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/ot-venv \
    && /opt/ot-venv/bin/pip install --no-cache-dir pymodbus==3.11.3

ENV PATH="/opt/ot-venv/bin:${PATH}"
CMD ["sleep", "infinity"]
