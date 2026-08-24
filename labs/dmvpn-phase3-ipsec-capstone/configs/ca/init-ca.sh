#!/bin/sh
# Create or validate the capstone CA without overwriting an incomplete workspace.
set -eu
umask 077

base=/lab/pki
script_dir=/opt/dmvpn-pki
ca_key="$base/private/dmvpn-ca.key"
ca_cert="$base/ca/dmvpn-ca.pem"

if [ -e "$base/.complete" ] || [ -e "$ca_key" ] || [ -e "$ca_cert" ]; then
    "$script_dir/validate-pki.sh" --ca-only >/dev/null || {
        echo "ERROR: the existing PKI workspace is incomplete or invalid; refusing to overwrite it" >&2
        exit 1
    }
    echo "Existing validated DMVPN CA reused."
    exit 0
fi

tmp=$(mktemp -d /lab/.dmvpn-ca.XXXXXX)
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
install -d -m 0700 "$tmp/ca" "$tmp/certs" "$tmp/csr" "$tmp/private" "$tmp/ext"

cat >"$tmp/ca.ext" <<'EOF'
[req]
distinguished_name = subject
x509_extensions = v3_ca
prompt = no

[subject]
C = CA
ST = Ontario
L = Toronto
O = ContainerLab
OU = DMVPN Capstone
CN = DMVPN Capstone Root CA

[v3_ca]
basicConstraints = critical,CA:true,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
    -out "$tmp/private/dmvpn-ca.key" >/dev/null 2>&1
openssl req -new -x509 -sha256 -days 3650 \
    -key "$tmp/private/dmvpn-ca.key" \
    -out "$tmp/ca/dmvpn-ca.pem" -config "$tmp/ca.ext" >/dev/null 2>&1
chmod 0600 "$tmp/private/dmvpn-ca.key" "$tmp/ca/dmvpn-ca.pem"

# Publish only after OpenSSL accepts the staged key/certificate pair and CA policy.
openssl pkey -in "$tmp/private/dmvpn-ca.key" -check -noout >/dev/null 2>&1
openssl verify -CAfile "$tmp/ca/dmvpn-ca.pem" "$tmp/ca/dmvpn-ca.pem" >/dev/null 2>&1
openssl x509 -in "$tmp/ca/dmvpn-ca.pem" -noout -text | \
    grep -q 'CA:TRUE, pathlen:0'

for directory in ca certs csr private ext; do
    mv "$tmp/$directory" "$base/$directory"
done
mv "$tmp/ca.ext" "$base/ca.ext"
: >"$base/.complete"
chmod 0600 "$base/.complete" "$base/ca.ext"
trap - EXIT HUP INT TERM
rm -rf "$tmp"
echo "Created validated DMVPN root CA."
