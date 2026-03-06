#!/bin/bash
# gen-certs.sh — generate CA, server, and client certs for dot1x-nac lab
# Run once from the configs/certs/ directory.
# Output files are committed to the repo (lab use only — 10-year validity).

set -e
cd "$(dirname "$0")"

echo "==> Generating CA key and certificate..."
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.pem \
  -subj "/C=US/ST=Lab/L=Lab/O=ContainerLab/CN=dot1x-nac-CA"

echo "==> Generating DH parameters (this may take a minute)..."
openssl dhparam -out dh 2048

echo "==> Generating server key and certificate..."
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=Lab/L=Lab/O=ContainerLab/CN=radius-server"
openssl x509 -req -days 3650 -in server.csr -CA ca.pem -CAkey ca.key \
  -CAcreateserial -out server.pem \
  -extfile <(printf "subjectAltName=DNS:radius-server\nextendedKeyUsage=serverAuth")
rm server.csr

echo "==> Generating client key and certificate (EAP-TLS supplicant)..."
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr \
  -subj "/C=US/ST=Lab/L=Lab/O=ContainerLab/CN=alice-tls"
openssl x509 -req -days 3650 -in client.csr -CA ca.pem -CAkey ca.key \
  -CAcreateserial -out client.pem \
  -extfile <(printf "extendedKeyUsage=clientAuth")
rm client.csr

echo ""
echo "==> Done. Files generated:"
ls -1 ca.pem server.pem server.key client.pem client.key dh
echo ""
echo "NOTE: ca.key is kept only for re-signing. It is not deployed to containers."
