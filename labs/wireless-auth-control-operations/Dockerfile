FROM debian:12.12-slim@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c

RUN apt-get update && apt-get install -y --no-install-recommends \
    bridge-utils \
    curl \
    freeradius \
    freeradius-utils \
    hostapd \
    iproute2 \
    iputils-ping \
    nftables \
    openssl \
    procps \
    python3 \
    tcpdump \
    wpasupplicant \
    && rm -rf /var/lib/apt/lists/*

# Disposable lab PKI: the private keys stay inside the locally built image, not
# in the repository. Clients receive only the golden CA certificate at runtime.
RUN set -eux; \
    mkdir -p /opt/lab-pki/golden /opt/lab-pki/untrusted; \
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
      -subj '/CN=wireless-auth-control-lab CA/O=ContainerLab' \
      -keyout /opt/lab-pki/golden/ca.key -out /opt/lab-pki/golden/ca.pem; \
    openssl req -newkey rsa:2048 -nodes -subj '/CN=radius.lab/O=ContainerLab' \
      -keyout /opt/lab-pki/golden/server.key -out /opt/lab-pki/golden/server.csr; \
    openssl x509 -req -days 3650 -in /opt/lab-pki/golden/server.csr \
      -CA /opt/lab-pki/golden/ca.pem -CAkey /opt/lab-pki/golden/ca.key -CAcreateserial \
      -out /opt/lab-pki/golden/server.pem; \
    for identity in corp-user quarantine-user; do \
      openssl req -newkey rsa:2048 -nodes -subj "/CN=$identity/O=ContainerLab" \
        -keyout "/opt/lab-pki/golden/$identity.key" -out "/tmp/$identity.csr"; \
      openssl x509 -req -days 3650 -in "/tmp/$identity.csr" \
        -CA /opt/lab-pki/golden/ca.pem -CAkey /opt/lab-pki/golden/ca.key -CAcreateserial \
        -out "/opt/lab-pki/golden/$identity.pem"; \
    done; \
    openssl dhparam -out /opt/lab-pki/golden/dh 2048; \
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
      -subj '/CN=untrusted-radius.lab/O=Break-It' \
      -keyout /opt/lab-pki/untrusted/server.key -out /opt/lab-pki/untrusted/server.pem; \
    cp /opt/lab-pki/golden/dh /opt/lab-pki/untrusted/dh; \
    rm -f /tmp/*.csr /opt/lab-pki/golden/*.csr /opt/lab-pki/golden/*.srl

CMD ["sleep", "infinity"]
