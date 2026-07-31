FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2=6.1.0-3 \
        iputils-ping=3:20221126-1+deb12u1 \
        nfdump=1.7.1-2+deb12u1 \
        procps=2:4.0.2-3 \
        rsyslog=8.2302.0-1+deb12u1 \
        snmp=5.9.3+dfsg-2+deb12u1 \
        softflowd=1.1.0-1+b1 \
        tcpdump=4.99.3-1 \
        tini=0.19.0-1+b3 \
    && rm -rf /var/lib/apt/lists/*

CMD ["/usr/bin/tini", "--", "sleep", "infinity"]
