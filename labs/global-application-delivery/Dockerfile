FROM coredns/coredns:1.12.2@sha256:af8c8d35a5d184b386c4a6d1a012c8b218d40d1376474c7d071bb6c07201f47d AS coredns

FROM alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1

RUN apk add --no-cache \
    bash=5.2.37-r0 \
    bind-tools=9.20.26-r0 \
    ca-certificates=20260611-r0 \
    curl=8.14.1-r3 \
    dnsmasq=2.91-r1 \
    haproxy=3.2.21-r0 \
    iproute2=6.15.0-r0 \
    iputils=20240905-r0 \
    jq=1.8.1-r0 \
    netcat-openbsd=1.229.1-r0 \
    nginx=1.28.3-r7 \
    openssl=3.5.7-r0 \
    python3=3.12.13-r0 \
    socat=1.8.1.3-r0 \
    tcpdump=4.99.5-r1

COPY --from=coredns /coredns /usr/local/bin/coredns

RUN set -eux; \
    mkdir -p /opt/gad/pki /opt/gad/tls; \
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
      -subj "/O=Networking Labs/CN=GAD Lab CA" \
      -keyout /opt/gad/pki/ca.key -out /opt/gad/pki/ca.crt; \
    for name in shop api; do \
      openssl req -newkey rsa:2048 -nodes \
        -subj "/O=Networking Labs/CN=${name}.gad.test" \
        -keyout "/opt/gad/pki/${name}.key" -out "/tmp/${name}.csr"; \
      printf 'subjectAltName=DNS:%s.gad.test\nextendedKeyUsage=serverAuth\n' "$name" >"/tmp/${name}.ext"; \
      openssl x509 -req -in "/tmp/${name}.csr" \
        -CA /opt/gad/pki/ca.crt -CAkey /opt/gad/pki/ca.key -CAcreateserial \
        -days 3650 -extfile "/tmp/${name}.ext" -out "/opt/gad/pki/${name}.crt"; \
      cat "/opt/gad/pki/${name}.crt" "/opt/gad/pki/${name}.key" >"/opt/gad/tls/${name}.pem"; \
    done; \
    rm -f /tmp/*.csr /tmp/*.ext /opt/gad/pki/ca.srl

CMD ["sleep", "infinity"]
