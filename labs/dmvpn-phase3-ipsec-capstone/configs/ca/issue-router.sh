#!/bin/sh
# Issue or validate one allow-listed router identity transactionally.
set -eu
umask 077

base=/lab/pki
router=${1:-}
fqdn=${2:-}

case "$router:$fqdn" in
    hub:hub.dmvpn.lab) serial=1001 ;;
    spoke1:spoke1.dmvpn.lab) serial=1002 ;;
    spoke2:spoke2.dmvpn.lab) serial=1003 ;;
    spoke3:spoke3.dmvpn.lab) serial=1004 ;;
    *)
        echo "ERROR: identity is not in the capstone router/FQDN allow-list" >&2
        exit 2
        ;;
esac

/opt/dmvpn-pki/validate-pki.sh --ca-only >/dev/null || {
    echo "ERROR: initialize a valid CA before issuing a router certificate" >&2
    exit 1
}

key="$base/private/$router.key"
csr="$base/csr/$router.csr"
cert="$base/certs/$router.pem"
ext="$base/ext/$router.ext"

existing=0
for path in "$key" "$csr" "$cert" "$ext"; do
    [ -e "$path" ] && existing=$((existing + 1))
done
if [ "$existing" -ne 0 ]; then
    [ "$existing" -eq 4 ] && /opt/dmvpn-pki/validate-pki.sh "$router" >/dev/null || {
        echo "ERROR: existing $router material is incomplete or invalid; refusing to overwrite it" >&2
        exit 1
    }
    echo "Existing validated certificate for $router reused."
    exit 0
fi

tmp=$(mktemp -d "/lab/.dmvpn-$router.XXXXXX")
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cat >"$tmp/$router.ext" <<EOF
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
subjectAltName = DNS:$fqdn
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
    -out "$tmp/$router.key" >/dev/null 2>&1
openssl req -new -sha256 -key "$tmp/$router.key" -out "$tmp/$router.csr" \
    -subj "/C=CA/ST=Ontario/L=Toronto/O=ContainerLab/OU=DMVPN Capstone/CN=$fqdn" \
    -addext "subjectAltName=DNS:$fqdn" >/dev/null 2>&1
openssl x509 -req -sha256 -days 825 -set_serial "$serial" \
    -in "$tmp/$router.csr" -CA "$base/ca/dmvpn-ca.pem" \
    -CAkey "$base/private/dmvpn-ca.key" -extfile "$tmp/$router.ext" \
    -out "$tmp/$router.pem" >/dev/null 2>&1
chmod 0600 "$tmp/$router.key" "$tmp/$router.csr" "$tmp/$router.pem" "$tmp/$router.ext"

openssl verify -CAfile "$base/ca/dmvpn-ca.pem" "$tmp/$router.pem" >/dev/null 2>&1
key_pub=$(openssl pkey -in "$tmp/$router.key" -pubout 2>/dev/null | openssl sha256)
cert_pub=$(openssl x509 -in "$tmp/$router.pem" -pubkey -noout 2>/dev/null | openssl sha256)
[ "$key_pub" = "$cert_pub" ] || {
    echo "ERROR: staged router key and certificate do not match" >&2
    exit 1
}

mv "$tmp/$router.key" "$key"
mv "$tmp/$router.csr" "$csr"
mv "$tmp/$router.pem" "$cert"
mv "$tmp/$router.ext" "$ext"
trap - EXIT HUP INT TERM
rm -rf "$tmp"
/opt/dmvpn-pki/validate-pki.sh "$router" >/dev/null
echo "Issued and validated certificate for $router ($fqdn)."
