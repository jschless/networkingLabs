FROM quay.io/frrouting/frr@sha256:fc7f887ab4d8da06f481a4f8d59afded88b3c5823f03610a7e808f7eba45eeea

USER root
RUN apk add --no-cache \
      bind bind-tools conntrack-tools curl iproute2 iputils jq nftables openssl \
      python3 tcpdump
