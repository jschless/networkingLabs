#!/bin/vbash
# shellcheck shell=bash disable=SC1091,SC2121
# Replace and save this router's complete learned PKI/DMVPN/IPsec state.
if ! source /opt/vyatta/etc/functions/script-template; then
    echo 'ERROR: VyOS configuration environment did not initialize' >&2
    exit 1
fi
# Do not enable errexit: the VyOS template uses successful alias/completion
# helpers whose arithmetic probes legitimately return nonzero. Guard every
# load-bearing precheck and transaction boundary explicitly instead.
set -uo pipefail

node=$(hostname)
stage=/tmp/dmvpn-capstone-pki
cleanup() {
    ca_body='' cert_body='' key_body=''
    rm -rf "$stage"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
case "$node" in
    hub) rank=0; wan=10.0.0.1; overlay=172.16.0.1; fqdn=hub.dmvpn.lab ;;
    spoke1) rank=1; wan=10.0.0.11; overlay=172.16.0.11; fqdn=spoke1.dmvpn.lab ;;
    spoke2) rank=2; wan=10.0.0.12; overlay=172.16.0.12; fqdn=spoke2.dmvpn.lab ;;
    spoke3) rank=3; wan=10.0.0.13; overlay=172.16.0.13; fqdn=spoke3.dmvpn.lab ;;
    *) echo 'ERROR: unexpected router identity' >&2; exit 1 ;;
esac

ca_file="$stage/ca/dmvpn-ca.pem"
cert_file="$stage/certs/$node.pem"
key_file="$stage/private/$node.key"
for file in "$ca_file" "$cert_file" "$key_file"; do
    [[ -f "$file" && "$(stat -c %a "$file")" == 600 ]] || {
        echo 'ERROR: protected PKI staging material is missing or unsafe' >&2
        exit 1
    }
done
if ! openssl verify -CAfile "$ca_file" "$cert_file" >/dev/null 2>&1; then
    echo 'ERROR: protected PKI staging chain validation failed' >&2
    exit 1
fi
if ! key_pub=$(openssl pkey -in "$key_file" -pubout 2>/dev/null | openssl sha256); then
    echo 'ERROR: protected PKI staging key validation failed' >&2
    exit 1
fi
if ! cert_pub=$(openssl x509 -in "$cert_file" -pubkey -noout 2>/dev/null | openssl sha256); then
    echo 'ERROR: protected PKI staging certificate validation failed' >&2
    exit 1
fi
[[ "$key_pub" == "$cert_pub" ]] || {
    echo 'ERROR: protected PKI staging key does not match its certificate' >&2
    exit 1
}

pem_body() { sed '/^-----/d' "$1" | tr -d '\n'; }
if ! ca_body=$(pem_body "$ca_file"); then
    echo 'ERROR: protected PKI CA import preparation failed' >&2
    exit 1
fi
if ! cert_body=$(pem_body "$cert_file"); then
    echo 'ERROR: protected PKI certificate import preparation failed' >&2
    exit 1
fi
if ! key_body=$(pem_body "$key_file"); then
    echo 'ERROR: protected PKI key import preparation failed' >&2
    exit 1
fi

if ! configure; then
    echo 'ERROR: VyOS configuration session did not start' >&2
    exit 1
fi
# Replacement must work from both the empty learner baseline and a previously
# solved/polluted learned subtree. VyOS reports a nonzero status when a delete
# target is already absent, so tolerate only these idempotent absence cases.
delete pki || true
delete protocols nhrp || true
delete protocols ospf || true
delete protocols static || true
delete vpn ipsec || true

set pki ca DMVPN-CA certificate "$ca_body"
set pki certificate "$node-cert" certificate "$cert_body"
set pki certificate "$node-cert" private key "$key_body"

set protocols nhrp tunnel tun0 network-id '1'
set protocols nhrp tunnel tun0 holdtime '300'
set protocols nhrp tunnel tun0 registration-no-unique
set protocols ospf parameters router-id "$wan"
set protocols ospf area 0 network "$overlay/32"
set protocols ospf interface tun0 network 'point-to-multipoint'

if [[ "$node" == hub ]]; then
    set protocols nhrp tunnel tun0 multicast dynamic
    set protocols nhrp tunnel tun0 redirect
    set protocols ospf interface eth1 passive
    set protocols ospf redistribute static
    set protocols ospf summary-address '192.168.0.0/16'
    set protocols static route 192.168.1.0/24 next-hop '172.16.0.11'
    set protocols static route 192.168.2.0/24 next-hop '172.16.0.12'
    set protocols static route 192.168.3.0/24 next-hop '172.16.0.13'
else
    set protocols nhrp tunnel tun0 nhs tunnel-ip '172.16.0.1' nbma '10.0.0.1'
    set protocols nhrp tunnel tun0 map tunnel-ip '172.16.0.1' nbma '10.0.0.1'
    set protocols nhrp tunnel tun0 multicast '10.0.0.1'
    set protocols nhrp tunnel tun0 shortcut
fi

set vpn ipsec ike-group DMVPN-IKE key-exchange 'ikev2'
set vpn ipsec ike-group DMVPN-IKE lifetime '3600'
set vpn ipsec ike-group DMVPN-IKE dead-peer-detection action 'restart'
set vpn ipsec ike-group DMVPN-IKE dead-peer-detection interval '30'
set vpn ipsec ike-group DMVPN-IKE dead-peer-detection timeout '120'
set vpn ipsec ike-group DMVPN-IKE proposal 10 encryption 'aes256'
set vpn ipsec ike-group DMVPN-IKE proposal 10 hash 'sha256'
set vpn ipsec ike-group DMVPN-IKE proposal 10 dh-group '14'
set vpn ipsec esp-group DMVPN-ESP mode 'transport'
set vpn ipsec esp-group DMVPN-ESP lifetime '3600'
set vpn ipsec esp-group DMVPN-ESP pfs 'dh-group14'
set vpn ipsec esp-group DMVPN-ESP proposal 10 encryption 'aes256'
set vpn ipsec esp-group DMVPN-ESP proposal 10 hash 'sha256'

for remote in hub spoke1 spoke2 spoke3; do
    [[ "$remote" == "$node" ]] && continue
    case "$remote" in
        hub) remote_rank=0; remote_wan=10.0.0.1; remote_fqdn=hub.dmvpn.lab ;;
        spoke1) remote_rank=1; remote_wan=10.0.0.11; remote_fqdn=spoke1.dmvpn.lab ;;
        spoke2) remote_rank=2; remote_wan=10.0.0.12; remote_fqdn=spoke2.dmvpn.lab ;;
        spoke3) remote_rank=3; remote_wan=10.0.0.13; remote_fqdn=spoke3.dmvpn.lab ;;
    esac
    connection_type=none
    (( rank < remote_rank )) && connection_type=initiate
    set vpn ipsec site-to-site peer "$remote" remote-address "$remote_wan"
    set vpn ipsec site-to-site peer "$remote" authentication mode 'x509'
    set vpn ipsec site-to-site peer "$remote" authentication local-id "$fqdn"
    set vpn ipsec site-to-site peer "$remote" authentication remote-id "$remote_fqdn"
    set vpn ipsec site-to-site peer "$remote" authentication x509 certificate "$node-cert"
    set vpn ipsec site-to-site peer "$remote" authentication x509 ca-certificate 'DMVPN-CA'
    set vpn ipsec site-to-site peer "$remote" connection-type "$connection_type"
    set vpn ipsec site-to-site peer "$remote" local-address "$wan"
    set vpn ipsec site-to-site peer "$remote" ike-group 'DMVPN-IKE'
    set vpn ipsec site-to-site peer "$remote" default-esp-group 'DMVPN-ESP'
    set vpn ipsec site-to-site peer "$remote" tunnel 1 protocol 'gre'
done

if ! commit; then
    echo 'ERROR: VyOS candidate configuration did not commit' >&2
    exit 1
fi
if ! save; then
    echo 'ERROR: committed VyOS configuration did not save' >&2
    exit 1
fi
exit
