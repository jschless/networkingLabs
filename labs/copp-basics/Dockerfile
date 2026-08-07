FROM quay.io/frrouting/frr@sha256:fc7f887ab4d8da06f481a4f8d59afded88b3c5823f03610a7e808f7eba45eeea

RUN apk add --no-cache \
        busybox=1.37.0-r20 \
        c-ares=1.34.8-r0 \
        iptables=1.8.11-r1 \
        musl=1.2.5-r12 \
        zlib=1.3.2-r0

CMD ["sleep", "infinity"]
