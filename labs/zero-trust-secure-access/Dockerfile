FROM python:3.12.7-alpine3.20@sha256:5049c050bdc68575a10bcb1885baa0689b6c15152d8a56a7e399fb49f783bf98

RUN apk add --no-cache bash curl iproute2 iputils nftables openssl tcpdump
COPY configs/common/ /opt/zt/
RUN chmod 0755 /opt/zt/*.sh /opt/zt/*.py
ENTRYPOINT ["/opt/zt/entrypoint.sh"]
