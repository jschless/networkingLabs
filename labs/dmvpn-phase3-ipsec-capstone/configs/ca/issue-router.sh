#!/bin/sh
set -e

BASE="${PKI_BASE:-/lab/pki}"
ROUTER="${1:-}"
FQDN="${2:-}"

if [ -z "$ROUTER" ] || [ -z "$FQDN" ]; then
  echo "Usage: $0 <router> <fqdn>" >&2
  exit 1
fi

CA_CERT="$BASE/ca/dmvpn-ca.pem"
CA_KEY="$BASE/private/dmvpn-ca.key"
ROUTER_KEY="$BASE/private/${ROUTER}.key"
ROUTER_CSR="$BASE/csr/${ROUTER}.csr"
ROUTER_CERT="$BASE/certs/${ROUTER}.pem"
ROUTER_EXT="$BASE/ext/${ROUTER}.ext"
INSTALL_SNIPPET="$BASE/install/${ROUTER}.commands"
CERT_NAME="${ROUTER}-cert"

if [ ! -f "$CA_CERT" ] || [ ! -f "$CA_KEY" ]; then
  echo "CA files are missing. Create $CA_CERT and $CA_KEY first." >&2
  exit 1
fi

openssl genrsa -out "$ROUTER_KEY" 2048
openssl req -new -key "$ROUTER_KEY" -out "$ROUTER_CSR" \
  -subj "/C=US/ST=Lab/L=Toronto/O=ContainerLab/CN=${FQDN}"

cat > "$ROUTER_EXT" <<EOF
subjectAltName=DNS:${FQDN}
extendedKeyUsage=serverAuth,clientAuth
EOF

openssl x509 -req -in "$ROUTER_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" \
  -CAcreateserial -out "$ROUTER_CERT" -days 825 -sha256 -extfile "$ROUTER_EXT"

# VyOS `set pki` takes the base64 BODY of the PEM (the text between the
# BEGIN/END armor lines), not a base64 of the whole file — stripping the
# armor and joining the lines produces exactly that. Re-encoding the full
# PEM makes commit fail with "Invalid certificate".
pem_body() { sed '/^-----/d' "$1" | tr -d '\n'; }

CA_B64="$(pem_body "$CA_CERT")"
CERT_B64="$(pem_body "$ROUTER_CERT")"
# The key must be PKCS#8 for VyOS; openssl genrsa emits PKCS#1 ("BEGIN RSA
# PRIVATE KEY"), so convert before stripping the armor.
KEY_B64="$(openssl pkcs8 -topk8 -nocrypt -in "$ROUTER_KEY" | sed '/^-----/d' | tr -d '\n')"

cat > "$INSTALL_SNIPPET" <<EOF
set pki ca DMVPN-CA certificate '${CA_B64}'
set pki certificate ${CERT_NAME} certificate '${CERT_B64}'
set pki certificate ${CERT_NAME} private key '${KEY_B64}'
EOF

chmod 600 "$ROUTER_KEY" "$INSTALL_SNIPPET"

echo "Issued certificate for $ROUTER ($FQDN)"
echo "Install snippet: $INSTALL_SNIPPET"
